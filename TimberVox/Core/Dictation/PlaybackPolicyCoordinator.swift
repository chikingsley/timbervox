import Foundation

/// What must happen at the end of a recording to undo the applied policy.
enum PlaybackRestoreAction: Equatable, Sendable {
  case none
  case setVolume(Float)
  case resumePlayers([String])
  case sendMediaKey
}

/// Applies a dictation mode's playback policy when recording starts and
/// restores the exact prior state when it stops or is cancelled. The pending
/// task is consumed exactly once, so a stale stop or double cancel can never
/// restore twice or clobber a newer recording's state.
@MainActor
final class PlaybackPolicyCoordinator {
  private let control: PlaybackControlling
  private var pending: Task<PlaybackRestoreAction, Never>?

  init(control: PlaybackControlling = SystemPlaybackControl()) {
    self.control = control
  }

  func apply(_ policy: PlaybackPolicy) {
    guard pending == nil else { return }
    let control = self.control
    pending = Task.detached(priority: .userInitiated) {
      Self.applyMechanism(policy, using: control)
    }
  }

  func restore() async {
    guard let pending else { return }
    self.pending = nil
    let action = await pending.value
    let control = self.control
    await Task.detached(priority: .userInitiated) {
      Self.performRestore(action, using: control)
    }.value
  }

  private nonisolated static func applyMechanism(
    _ policy: PlaybackPolicy,
    using control: PlaybackControlling
  ) -> PlaybackRestoreAction {
    switch policy {
    case .keepPlaying:
      return .none
    case .lowerVolume:
      guard let volume = control.outputVolume() else { return .none }
      control.setOutputVolume(volume * 0.25)
      return .setVolume(volume)
    case .mute:
      guard let volume = control.outputVolume() else { return .none }
      control.setOutputVolume(0)
      return .setVolume(volume)
    case .pauseMedia:
      guard control.isAudioPlayingOnDefaultOutput() else { return .none }
      let paused = control.pauseKnownMediaPlayers()
      if !paused.isEmpty {
        return .resumePlayers(paused)
      }
      if control.isAudioPlayingOnDefaultOutput(), control.sendMediaPlayPauseKey() {
        return .sendMediaKey
      }
      return .none
    }
  }

  private nonisolated static func performRestore(
    _ action: PlaybackRestoreAction,
    using control: PlaybackControlling
  ) {
    switch action {
    case .none:
      break
    case .setVolume(let volume):
      control.setOutputVolume(volume)
    case .resumePlayers(let players):
      control.resumeMediaPlayers(players)
    case .sendMediaKey:
      _ = control.sendMediaPlayPauseKey()
    }
  }
}
