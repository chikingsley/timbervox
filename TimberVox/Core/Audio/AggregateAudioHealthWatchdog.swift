import Foundation

final class AggregateAudioHealthWatchdog: @unchecked Sendable {
  private let queue = DispatchQueue(
    label: "studio.peacockery.timbervox.aggregate-audio-health",
    qos: .userInitiated
  )
  private var timer: DispatchSourceTimer?

  func start(
    bridge: AggregateAudioBridge,
    onFailure: @escaping @Sendable () -> Void
  ) {
    stop()
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + 1.5, repeating: 0.5)
    timer.setEventHandler { [bridge] in
      guard bridge.hasValidInputTimedOut(after: 1.5) else { return }
      onFailure()
    }
    self.timer = timer
    timer.resume()
  }

  func stop() {
    timer?.cancel()
    timer = nil
    queue.sync {}
  }
}
