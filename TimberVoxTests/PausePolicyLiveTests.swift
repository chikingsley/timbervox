@preconcurrency import AVFoundation
import XCTest

@testable import TimberVox

/// Real-media Pause acceptance. QuickTime Player plays a tone as a genuine
/// media app (it is deliberately not in the scripted whitelist, so this
/// exercises the media-key tier). The Pause policy must silence the captured
/// system-audio stream mid-recording, and restore must bring the audio back.
@MainActor
final class PausePolicyLiveTests: XCTestCase {
  func testPausePolicySilencesRealMediaAndRestoreResumesIt() async throws {
    try LiveAudioTest.requirePauseAcceptance()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let toneURL = directory.appendingPathComponent("tone.wav")
    try LiveAudioTest.writeTone(to: toneURL, frequency: 880, seconds: 30)

    try LiveAudioTest.startQuickTimePlaying(toneURL)
    defer { LiveAudioTest.quitQuickTime() }

    let recorder = AggregateAudioRecorder()
    let systemURL = directory.appendingPathComponent("system.wav")
    try recorder.start(
      writingTo: directory.appendingPathComponent("mixed.wav"),
      microphoneURL: directory.appendingPathComponent("microphone.wav"),
      systemURL: systemURL,
      onLevel: nil,
      onSamples: nil
    )

    let coordinator = PlaybackPolicyCoordinator()
    try await Task.sleep(for: .seconds(2))
    coordinator.apply(.pauseMedia)
    try await Task.sleep(for: .seconds(3))
    await coordinator.restore()
    try await Task.sleep(for: .seconds(3.5))
    _ = try XCTUnwrap(recorder.finish())

    let system = try LiveAudioTest.samples(at: systemURL)
    let sampleRate = AggregateAudioFormat.sampleRate
    let playing = LiveAudioTest.tonePower(in: system, seconds: 0.5...1.8, sampleRate: sampleRate)
    let paused = LiveAudioTest.tonePower(in: system, seconds: 3.6...4.8, sampleRate: sampleRate)
    let resumed = LiveAudioTest.tonePower(in: system, seconds: 7.0...8.2, sampleRate: sampleRate)

    XCTAssertGreaterThan(
      playing,
      paused * 10,
      "Pause must silence the captured system audio while media was playing."
    )
    XCTAssertGreaterThan(
      resumed,
      paused * 10,
      "Restore must resume the paused media after the recording ends."
    )
  }
}
