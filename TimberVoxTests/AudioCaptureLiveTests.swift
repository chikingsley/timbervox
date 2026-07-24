@preconcurrency import AVFoundation
import XCTest

@testable import TimberVox

final class AudioCaptureLiveTests: XCTestCase {
  func testMicrophoneOnlyRecordingStartsAndFinishes() async throws {
    try LiveAudioTest.requireLiveCapture()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let outputURL = directory.appendingPathComponent("microphone.wav")
    let recorder = DictationAudioRecorder()

    try await recorder.start(writingTo: outputURL, includesSystemAudio: false)
    try await Task.sleep(for: .seconds(1))
    let finishedRecording = try await recorder.finish()
    let recording = try XCTUnwrap(finishedRecording)
    let file = try AVAudioFile(forReading: recording.url)

    XCTAssertEqual(file.processingFormat.sampleRate, 16_000)
    XCTAssertEqual(file.processingFormat.channelCount, 1)
    XCTAssertGreaterThan(recording.duration, 0.8)
  }

  func testMicrophoneAndSystemAudioProduceMixedRecording() async throws {
    try LiveAudioTest.requireLiveCapture()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let toneURL = directory.appendingPathComponent("tone.wav")
    let outputURL = directory.appendingPathComponent("mixed.wav")
    try LiveAudioTest.writeTone(to: toneURL, frequency: 880)
    let player = try AVAudioPlayer(contentsOf: toneURL)
    let recorder = DictationAudioRecorder()

    try await recorder.start(writingTo: outputURL, includesSystemAudio: true)
    player.play()
    try await Task.sleep(for: .seconds(1))
    let recording = try await recorder.finish()

    let result = try XCTUnwrap(recording)
    let file = try AVAudioFile(forReading: result.url)
    XCTAssertEqual(file.processingFormat.sampleRate, 16_000)
    XCTAssertEqual(file.processingFormat.channelCount, 1)
    XCTAssertGreaterThan(result.duration, 0.8)
  }

  /// Signal-level acceptance: the played tone must dominate the system stem and
  /// appear in the mixed master, while the microphone stem carries live input.
  func testSystemToneIsIsolatedInSystemStemAndPresentInMix() async throws {
    try LiveAudioTest.requireLiveCapture()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let toneURL = directory.appendingPathComponent("tone.wav")
    try LiveAudioTest.writeTone(to: toneURL, frequency: 880, seconds: 1.2)
    let player = try AVAudioPlayer(contentsOf: toneURL)
    let recorder = AggregateAudioRecorder()
    let mixedURL = directory.appendingPathComponent("mixed.wav")
    let microphoneURL = directory.appendingPathComponent("microphone.wav")
    let systemURL = directory.appendingPathComponent("system.wav")

    try recorder.start(
      writingTo: mixedURL,
      microphoneURL: microphoneURL,
      systemURL: systemURL,
      onLevel: nil,
      onSamples: nil
    )
    player.play()
    try await Task.sleep(for: .seconds(1.4))
    let recording = try XCTUnwrap(recorder.finish())

    let system = try LiveAudioTest.samples(at: systemURL)
    let microphone = try LiveAudioTest.samples(at: microphoneURL)
    let mixed = try LiveAudioTest.samples(at: recording.url)
    let sampleRate = AggregateAudioFormat.sampleRate

    let systemTone = LiveAudioTest.power(of: system, atHertz: 880, sampleRate: sampleRate)
    let systemOffTone = LiveAudioTest.power(of: system, atHertz: 500, sampleRate: sampleRate)
    XCTAssertGreaterThan(
      systemTone,
      systemOffTone * 10,
      "The 880 Hz tone must dominate the system stem, not merely register as energy."
    )

    let mixedTone = LiveAudioTest.power(of: mixed, atHertz: 880, sampleRate: sampleRate)
    let mixedOffTone = LiveAudioTest.power(of: mixed, atHertz: 500, sampleRate: sampleRate)
    XCTAssertGreaterThan(
      mixedTone,
      mixedOffTone * 5,
      "The system tone must survive into the mixed master."
    )

    XCTAssertGreaterThan(
      LiveAudioTest.rootMeanSquare(microphone),
      0.000_1,
      "The microphone stem must carry live input, not silence."
    )
  }

  /// Cancel must fully release the tap and aggregate device: the deleted
  /// files prove cleanup, and an immediate second recording proves the
  /// hardware was genuinely torn down, not leaked.
  func testCancelReleasesHardwareForImmediateRestart() async throws {
    try LiveAudioTest.requireLiveCapture()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cancelled = AggregateAudioRecorder()
    let cancelledURL = directory.appendingPathComponent("cancelled.wav")
    try cancelled.start(
      writingTo: cancelledURL,
      microphoneURL: directory.appendingPathComponent("cancelled-microphone.wav"),
      systemURL: directory.appendingPathComponent("cancelled-system.wav"),
      onLevel: nil,
      onSamples: nil
    )
    try await Task.sleep(for: .milliseconds(500))
    cancelled.cancel()
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: cancelledURL.path),
      "Cancel must delete the partial recording."
    )

    let toneURL = directory.appendingPathComponent("tone.wav")
    try LiveAudioTest.writeTone(to: toneURL, frequency: 880)
    let player = try AVAudioPlayer(contentsOf: toneURL)
    let restarted = AggregateAudioRecorder()
    let systemURL = directory.appendingPathComponent("system.wav")
    try restarted.start(
      writingTo: directory.appendingPathComponent("mixed.wav"),
      microphoneURL: directory.appendingPathComponent("microphone.wav"),
      systemURL: systemURL,
      onLevel: nil,
      onSamples: nil
    )
    player.play()
    try await Task.sleep(for: .seconds(1.2))
    let recording = try XCTUnwrap(restarted.finish())
    XCTAssertGreaterThan(recording.duration, 0.8)
    let system = try LiveAudioTest.samples(at: systemURL)
    XCTAssertGreaterThan(
      LiveAudioTest.power(of: system, atHertz: 880, sampleRate: AggregateAudioFormat.sampleRate),
      LiveAudioTest.power(of: system, atHertz: 500, sampleRate: AggregateAudioFormat.sampleRate) * 10,
      "A recording started immediately after cancel must capture system audio normally."
    )
  }

  /// Switching the default output device mid-recording must not interrupt
  /// capture: the tone must be present in the system stem both before and
  /// after the switch.
  func testCaptureSurvivesDefaultOutputDeviceSwitch() async throws {
    try LiveAudioTest.requireLiveCapture()
    let outputs = LiveAudioTest.outputDeviceIDs()
    guard
      let original = LiveAudioTest.defaultOutputDeviceID(),
      let other = outputs.first(where: { $0 != original })
    else {
      throw XCTSkip("This machine does not expose two output devices.")
    }
    defer { LiveAudioTest.setDefaultOutputDevice(original) }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let toneURL = directory.appendingPathComponent("tone.wav")
    try LiveAudioTest.writeTone(to: toneURL, frequency: 880, seconds: 6)
    let player = try AVAudioPlayer(contentsOf: toneURL)
    let recorder = AggregateAudioRecorder()
    let systemURL = directory.appendingPathComponent("system.wav")
    try recorder.start(
      writingTo: directory.appendingPathComponent("mixed.wav"),
      microphoneURL: directory.appendingPathComponent("microphone.wav"),
      systemURL: systemURL,
      onLevel: nil,
      onSamples: nil
    )
    player.play()
    try await Task.sleep(for: .seconds(2))
    LiveAudioTest.setDefaultOutputDevice(other)
    try await Task.sleep(for: .seconds(2.5))
    _ = try XCTUnwrap(recorder.finish())

    let system = try LiveAudioTest.samples(at: systemURL)
    let sampleRate = AggregateAudioFormat.sampleRate
    let before = LiveAudioTest.tonePower(in: system, seconds: 0.5...1.8, sampleRate: sampleRate)
    let after = LiveAudioTest.tonePower(in: system, seconds: 3.0...4.3, sampleRate: sampleRate)
    XCTAssertGreaterThan(before, 0, "The tone must be captured before the output switch.")
    XCTAssertGreaterThan(
      after,
      before * 0.01,
      "Capture must continue after the default output device changes."
    )
  }

  /// The production Core Audio tap and real output device feed this test. A
  /// deliberately slow production callback must not create unbounded queued
  /// work; the bridge drops synchronized chunks and reports degradation.
  func testSlowRealtimeConsumerIsBoundedAndReported() async throws {
    try LiveAudioTest.requireLiveCapture()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let toneURL = directory.appendingPathComponent("tone.wav")
    try LiveAudioTest.writeTone(to: toneURL, frequency: 880, seconds: 2)
    let player = try AVAudioPlayer(contentsOf: toneURL)
    let recorder = AggregateAudioRecorder()
    let systemURL = directory.appendingPathComponent("system.wav")

    try recorder.start(
      writingTo: directory.appendingPathComponent("mixed.wav"),
      microphoneURL: directory.appendingPathComponent("microphone.wav"),
      systemURL: systemURL,
      onLevel: nil
    ) { _ in
      Thread.sleep(forTimeInterval: 0.05)
    }
    player.play()
    try await Task.sleep(for: .seconds(1.5))
    let recording = try XCTUnwrap(recorder.finish())

    XCTAssertGreaterThan(recording.duration, 0.2, "The bounded bridge must still deliver real audio.")
    XCTAssertGreaterThan(
      recorder.captureDiagnostics.droppedChunks,
      0,
      "A consumer running far below the hardware callback rate must enter the explicit degraded state."
    )
    XCTAssertEqual(
      recorder.captureDiagnostics.oversizedChunks,
      0,
      "Normal hardware buffers must fit the preallocated slots."
    )
    let system = try LiveAudioTest.samples(at: systemURL)
    XCTAssertGreaterThan(
      LiveAudioTest.power(of: system, atHertz: 880, sampleRate: AggregateAudioFormat.sampleRate),
      0,
      "The bounded path must contain the tone captured from the actual system output."
    )
  }

  /// Real capture begins in silence, receives a system tone later, and then
  /// continues after playback ends. This checks start/stop alignment without
  /// injecting fabricated buffers into the mixer.
  func testDelayedSystemAudioStartAndStopPreserveTimeline() async throws {
    try LiveAudioTest.requireLiveCapture()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let toneURL = directory.appendingPathComponent("tone.wav")
    try LiveAudioTest.writeTone(to: toneURL, frequency: 880, seconds: 0.8)
    let player = try AVAudioPlayer(contentsOf: toneURL)
    let recorder = AggregateAudioRecorder()
    let systemURL = directory.appendingPathComponent("system.wav")

    try recorder.start(
      writingTo: directory.appendingPathComponent("mixed.wav"),
      microphoneURL: directory.appendingPathComponent("microphone.wav"),
      systemURL: systemURL,
      onLevel: nil,
      onSamples: nil
    )
    try await Task.sleep(for: .milliseconds(500))
    player.play()
    try await Task.sleep(for: .seconds(1.3))
    let recording = try XCTUnwrap(recorder.finish())

    XCTAssertGreaterThan(recording.duration, 1.6)
    XCTAssertFalse(recorder.captureDiagnostics.isDegraded)
    let system = try LiveAudioTest.samples(at: systemURL)
    let sampleRate = AggregateAudioFormat.sampleRate
    let before = LiveAudioTest.tonePower(
      in: system,
      seconds: 0.05...0.35,
      sampleRate: sampleRate
    )
    let during = LiveAudioTest.tonePower(
      in: system,
      seconds: 0.65...1.05,
      sampleRate: sampleRate
    )
    let after = LiveAudioTest.tonePower(
      in: system,
      seconds: 1.45...1.7,
      sampleRate: sampleRate
    )
    XCTAssertGreaterThan(during, max(before, after) * 20)
  }
}
