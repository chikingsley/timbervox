@preconcurrency import AVFoundation
import FluidAudio
import XCTest

@testable import TimberVox

final class LocalModelEnduranceLiveTests: XCTestCase {
  func testHummingbirdRejectsRealSilentAudio() async throws {
    try requireAcceptance()
    try await prepare(.batch(.parakeetTdtCtc110M))
    let fixture = try makeSilentFixture(duration: 4)
    defer { try? FileManager.default.removeItem(at: fixture) }
    ModelHub.offlineMode = true
    defer { ModelHub.offlineMode = false }

    let artifact = try await FluidAudioBatchTranscriber.shared.transcribe(
      wavAt: fixture,
      route: .parakeetTdtCtc110M
    )
    XCTAssertTrue(artifact.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }

  func testHummingbirdTranscribesLongSpeechThroughTheFinalPhrase() async throws {
    try requireAcceptance()
    try await prepare(.batch(.parakeetTdtCtc110M))
    let repeated = Array(
      repeating: "Purple elephant walks through the quiet garden.",
      count: 24
    ).joined(separator: " ")
    let fixture = try makeSpeechFixture(text: repeated + " Silver waterfall marks the end.")
    defer { try? FileManager.default.removeItem(at: fixture) }
    ModelHub.offlineMode = true
    defer { ModelHub.offlineMode = false }

    let transcript = try await FluidAudioBatchTranscriber.shared.transcribe(
      wavAt: fixture,
      route: .parakeetTdtCtc110M
    )
    let normalized = normalize(transcript.displayText)
    XCTAssertTrue(normalized.contains("elephant"), transcript.displayText)
    XCTAssertTrue(normalized.contains("waterfall"), transcript.displayText)
  }

  func testNemotronCancellationCanStartAFreshRealSession() async throws {
    try requireAcceptance()
    let route = LocalTranscriptionRouteID.nemotronEnglish560
    try await prepare(.realtime(route, language: "en"))
    let fixture = try makeSpeechFixture(text: "Purple elephant marmalade sandwich")
    defer { try? FileManager.default.removeItem(at: fixture) }
    let samples = try AudioConverter().resampleAudioFile(fixture)
    let session = FluidAudioRealtimeTranscriptionSession.shared
    ModelHub.offlineMode = true
    defer { ModelHub.offlineMode = false }

    try await session.start(route: route, language: "en") { _ in }
    try await session.sendPCM(Array(samples.prefix(samples.count / 2)))
    await session.cancel()

    try await session.start(route: route, language: "en") { _ in }
    try await session.sendPCM(samples)
    let transcript = try await session.finish()
    XCTAssertTrue(normalize(transcript.displayText).contains("elephant"), transcript.displayText)
  }

  func testFluidAudioOfflinePreparationFailureIsBounded() async throws {
    try requireAcceptance()
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("timbervox-missing-model-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    ModelHub.offlineMode = true
    defer { ModelHub.offlineMode = false }
    let clock = ContinuousClock()
    let started = clock.now

    do {
      _ = try await AsrModels.downloadAndLoad(
        to: directory,
        version: .tdtCtc110m
      )
      XCTFail("A missing model unexpectedly prepared with network access disabled.")
    } catch {
      XCTAssertLessThan(started.duration(to: clock.now), .seconds(5))
    }
  }

  private func prepare(_ asset: FluidAudioModelAsset) async throws {
    let backend = FluidAudioModelAssetBackend()
    try await backend.prepare(asset) { _ in }
    let state = await backend.state(of: asset)
    XCTAssertEqual(state, .verified)
  }

  private func requireAcceptance() throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: "/tmp/timbervox-live-local-endurance"),
      "Touch /tmp/timbervox-live-local-endurance to run real local endurance acceptance."
    )
  }

  private func makeSilentFixture(duration: TimeInterval) throws -> URL {
    let output = FileManager.default.temporaryDirectory
      .appendingPathComponent("timbervox-silence-\(UUID().uuidString).wav")
    let format = try XCTUnwrap(
      AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
      )
    )
    let frameCount = AVAudioFrameCount(duration * format.sampleRate)
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
    buffer.frameLength = frameCount
    buffer.floatChannelData?[0].initialize(repeating: 0, count: Int(frameCount))
    let file = try AVAudioFile(forWriting: output, settings: format.settings)
    try file.write(from: buffer)
    return output
  }

  private func makeSpeechFixture(text: String) throws -> URL {
    let output = FileManager.default.temporaryDirectory
      .appendingPathComponent("timbervox-endurance-\(UUID().uuidString).aiff")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    process.arguments = ["-v", "Samantha", "-r", "220", "-o", output.path, text]
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0)
    return output
  }

  private func normalize(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
  }
}
