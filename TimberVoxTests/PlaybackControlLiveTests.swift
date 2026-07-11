import XCTest

@testable import TimberVox

/// Exercises the real Core Audio playback control: mute must drive the actual
/// output volume to zero and restore must bring back the exact prior value.
@MainActor
final class PlaybackControlLiveTests: XCTestCase {
  func testMutePolicyDrivesRealOutputVolumeToZeroAndRestoresIt() async throws {
    try LiveAudioTest.requireLiveCapture()
    let control = SystemPlaybackControl()
    guard let priorVolume = control.outputVolume() else {
      throw XCTSkip("The default output device has no volume control.")
    }
    defer { control.setOutputVolume(priorVolume) }
    let coordinator = PlaybackPolicyCoordinator(control: control)

    coordinator.apply(.mute)
    try await Task.sleep(for: .milliseconds(500))
    let muted = try XCTUnwrap(control.outputVolume())
    XCTAssertEqual(muted, 0, accuracy: 0.01, "Mute must drive the real output volume to zero.")

    await coordinator.restore()
    let restored = try XCTUnwrap(control.outputVolume())
    XCTAssertEqual(
      restored,
      priorVolume,
      accuracy: 0.01,
      "Restore must bring back the exact prior output volume."
    )
  }
}
