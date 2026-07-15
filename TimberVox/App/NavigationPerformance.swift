import Foundation
import os

/// Measures user-perceived navigation from the initiating action through populated content.
enum NavigationPerformance {
  static let subsystem = "com.chiejimofor.timbervox"
  static let category = "navigation"
  static let homeToHistoryName: StaticString = "HomeToHistory"
  static let historyQueryName: StaticString = "HistoryQuery"

  private static let signpostLog = OSLog(subsystem: subsystem, category: category)
  @MainActor private static var intervalID: OSSignpostID?
  @MainActor private static var startedAt: CFAbsoluteTime?

  @MainActor
  static func beginHomeToHistory() {
    let signpostID = OSSignpostID(log: signpostLog)
    intervalID = signpostID
    startedAt = CFAbsoluteTimeGetCurrent()
    os_signpost(
      .begin,
      log: signpostLog,
      name: homeToHistoryName,
      signpostID: signpostID
    )
  }

  @MainActor
  static func historyContentReady(itemCount: Int, queryMilliseconds: Double) {
    guard let intervalID, let startedAt else { return }
    let totalMilliseconds = (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000
    os_signpost(
      .end,
      log: signpostLog,
      name: homeToHistoryName,
      signpostID: intervalID,
      "items=%{public}ld query_ms=%{public}.2f",
      itemCount,
      queryMilliseconds
    )
    TimberVoxLog.navigation.info(
      "Home to populated History: \(totalMilliseconds, format: .fixed(precision: 1)) ms; database query: \(queryMilliseconds, format: .fixed(precision: 1)) ms; items: \(itemCount)"
    )
    self.intervalID = nil
    self.startedAt = nil
  }

  static func measureHistoryQuery<Result>(
    _ operation: () throws -> Result
  ) rethrows -> (Result, Double) {
    let signpostID = OSSignpostID(log: signpostLog)
    let startedAt = CFAbsoluteTimeGetCurrent()
    os_signpost(
      .begin,
      log: signpostLog,
      name: historyQueryName,
      signpostID: signpostID
    )
    let result = try operation()
    let milliseconds = (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000
    os_signpost(
      .end,
      log: signpostLog,
      name: historyQueryName,
      signpostID: signpostID
    )
    return (result, milliseconds)
  }
}
