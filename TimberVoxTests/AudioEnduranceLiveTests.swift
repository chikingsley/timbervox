@preconcurrency import AVFoundation
import XCTest

@testable import TimberVox

/// Ten minutes of continuous real capture with looping system audio. Memory
/// must stay bounded after warm-up, capture must still be live at the end,
/// and the canonical recording must cover the full duration.
@MainActor
final class AudioEnduranceLiveTests: XCTestCase {
  private static let runSeconds = 600.0
  private static let sampleInterval = 30.0
  private static let allowedGrowthBytes = 150.0 * 1024 * 1024

  func testTenMinuteCaptureStaysBoundedAndAlive() async throws {
    try LiveAudioTest.requireEndurance()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let toneURL = directory.appendingPathComponent("tone.wav")
    try LiveAudioTest.writeTone(to: toneURL, frequency: 880, seconds: 30)
    let player = try AVAudioPlayer(contentsOf: toneURL)
    player.numberOfLoops = -1

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

    var footprints: [Double] = []
    var elapsed = 0.0
    while elapsed < Self.runSeconds {
      try await Task.sleep(for: .seconds(Self.sampleInterval))
      elapsed += Self.sampleInterval
      if let footprint = LiveAudioTest.physicalFootprint() {
        footprints.append(footprint)
      }
    }
    player.stop()
    let recording = try XCTUnwrap(recorder.finish())

    XCTAssertGreaterThan(
      recording.duration,
      Self.runSeconds - 10,
      "The recording must cover the full endurance window."
    )
    let system = try LiveAudioTest.samples(at: systemURL)
    let sampleRate = AggregateAudioFormat.sampleRate
    let tail = (Self.runSeconds - 8)...(Self.runSeconds - 1)
    XCTAssertGreaterThan(
      LiveAudioTest.tonePower(in: system, seconds: tail, sampleRate: sampleRate),
      0,
      "Capture must still be receiving the tone in the final seconds."
    )

    guard let warm = footprints.dropFirst().first, let final = footprints.last else {
      return XCTFail("Memory footprint sampling failed.")
    }
    XCTAssertLessThan(
      final - warm,
      Self.allowedGrowthBytes,
      "Memory grew \(Int((final - warm) / 1024 / 1024)) MB after warm-up — capture must stay bounded."
    )
  }
}
