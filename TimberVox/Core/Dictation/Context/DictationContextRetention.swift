import Foundation

/// How long captured context attachments (screenshots and clipboard images)
/// stay on disk. Transcripts themselves are never deleted automatically.
enum DictationContextRetentionPreference {
  static let key = "contextAttachmentRetentionDays"
  static let defaultDays = 30

  static var retentionDays: Int {
    let saved = UserDefaults.standard.object(forKey: key) as? Int
    return saved ?? defaultDays
  }
}

enum DictationContextRetentionOption: Int, CaseIterable, Identifiable {
  case oneWeek = 7
  case oneMonth = 30
  case threeMonths = 90
  case forever = 0

  var id: Int { rawValue }

  var label: String {
    switch self {
    case .oneWeek: "1 week"
    case .oneMonth: "30 days"
    case .threeMonths: "90 days"
    case .forever: "Forever"
    }
  }
}

/// Deletes context attachment files older than the retention window. Every
/// file in ContextAttachments is app-created (screen and clipboard captures
/// copied at dictation time), so age alone decides what goes.
enum DictationContextRetentionSweeper {
  @discardableResult
  static func sweep(
    retentionDays: Int = DictationContextRetentionPreference.retentionDays,
    directory: URL? = nil,
    now: Date = .now
  ) -> Int {
    guard retentionDays > 0 else { return 0 }
    guard let directory = directory ?? defaultDirectory() else { return 0 }
    let cutoff = now.addingTimeInterval(-TimeInterval(retentionDays) * 24 * 60 * 60)
    let fileManager = FileManager.default
    guard
      let files = try? fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.contentModificationDateKey]
      )
    else { return 0 }
    var removedCount = 0
    for file in files {
      guard
        let modifiedAt = try? file.resourceValues(forKeys: [.contentModificationDateKey])
          .contentModificationDate,
        modifiedAt < cutoff
      else { continue }
      do {
        try fileManager.removeItem(at: file)
        removedCount += 1
      } catch {
        TimberVoxLog.dictation.error(
          "Context attachment sweep could not remove \(file.lastPathComponent): \(error.localizedDescription)"
        )
      }
    }
    if removedCount > 0 {
      TimberVoxLog.dictation.info("Context attachment sweep removed \(removedCount) file(s).")
    }
    return removedCount
  }

  private static func defaultDirectory() -> URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first?
      .appendingPathComponent("TimberVox/ContextAttachments", isDirectory: true)
  }
}
