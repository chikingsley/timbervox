@preconcurrency import AVFoundation
import AppKit
import FluidAudio
import XCTest

@testable import TimberVox

final class LocalModelLiveAcceptanceTests: XCTestCase {
  func testHummingbirdBatchDownloadsPersistsAndTranscribesOffline() async throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: "/tmp/timbervox-live-local-model"),
      "Touch /tmp/timbervox-live-local-model to run local batch acceptance."
    )

    let backend = FluidAudioLocalModelAssetBackend()
    let asset = LocalModelAsset.batch(.parakeetTdtCtc110M)
    try await backend.prepare(asset) { _ in }
    let preparedState = await backend.state(of: asset)
    XCTAssertEqual(preparedState, .verified)

    let relaunchedBackend = FluidAudioLocalModelAssetBackend()
    let relaunchedState = await relaunchedBackend.state(of: asset)
    XCTAssertEqual(relaunchedState, .verified)

    let fixture = try makeSpeechFixture()
    defer { try? FileManager.default.removeItem(at: fixture) }
    ModelHub.offlineMode = true
    defer { ModelHub.offlineMode = false }

    let transcript = try await LocalBatchTranscriptionClient().transcribe(
      wavAt: fixture,
      route: .parakeetTdtCtc110M
    )

    XCTAssertTrue(transcript.lowercased().contains("purple elephant"))
  }

  func testHummingbirdPackageDownloadsAndPersists() async throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: "/tmp/timbervox-live-local-package"),
      "Touch /tmp/timbervox-live-local-package to run the complete package acceptance."
    )

    let store = await LocalModelPackageStore(backend: FluidAudioLocalModelAssetBackend())
    await store.download(modelID: "local-hummingbird")
    let state = await store.state(for: "local-hummingbird")
    XCTAssertEqual(state, .ready)

    let relaunchedStore = await LocalModelPackageStore(backend: FluidAudioLocalModelAssetBackend())
    await relaunchedStore.refresh(modelID: "local-hummingbird")
    let relaunchedState = await relaunchedStore.state(for: "local-hummingbird")
    XCTAssertEqual(relaunchedState, .ready)
  }

  func testParakeetV3DownloadsAndTranscribes() async throws {
    try requireMatrixAcceptance()
    let route = LocalTranscriptionRouteID.parakeetTdtV3
    try await prepare(.batch(route))

    let fixture = try makeSpeechFixture()
    defer { try? FileManager.default.removeItem(at: fixture) }
    ModelHub.offlineMode = true
    defer { ModelHub.offlineMode = false }

    let transcript = try await LocalBatchTranscriptionClient().transcribe(
      wavAt: fixture,
      route: route
    )
    try assertEnglishTranscript(transcript)
  }

  func testNemotronEnglish560DownloadsAndTranscribes() async throws {
    try requireMatrixAcceptance()
    try await assertRealtimeTranscript(route: .nemotronEnglish560, language: "en")
  }

  func testNemotronEnglish1120DownloadsAndTranscribes() async throws {
    try requireMatrixAcceptance()
    try await assertRealtimeTranscript(route: .nemotronEnglish1120, language: "en")
  }

  func testNemotronMultilingualLatinDownloadsAndTranscribes() async throws {
    try requireMatrixAcceptance()
    try await assertRealtimeTranscript(route: .nemotronMultilingual1120, language: "en")
  }

  func testNemotronMultilingualFullDownloadsAndTranscribesJapanese() async throws {
    try requireMatrixAcceptance()
    let route = LocalTranscriptionRouteID.nemotronMultilingual1120
    try await prepare(.realtime(route, language: "ja"))

    let fixture = try makeSpeechFixture(
      text: "紫の象が静かな庭を歩いています",
      voice: "Kyoko"
    )
    defer { try? FileManager.default.removeItem(at: fixture) }
    let samples = try AudioConverter().resampleAudioFile(fixture)
    ModelHub.offlineMode = true
    defer { ModelHub.offlineMode = false }

    let session = LocalRealtimeTranscriptionSession.shared
    try await session.start(route: route, language: "ja") { _ in }
    try await session.sendPCM(samples)
    let transcript = try await session.finish()
    XCTAssertFalse(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }

  private func assertRealtimeTranscript(
    route: LocalTranscriptionRouteID,
    language: String
  ) async throws {
    try await prepare(.realtime(route, language: language))
    let fixture = try makeSpeechFixture()
    defer { try? FileManager.default.removeItem(at: fixture) }
    let samples = try AudioConverter().resampleAudioFile(fixture)
    ModelHub.offlineMode = true
    defer { ModelHub.offlineMode = false }

    let session = LocalRealtimeTranscriptionSession.shared
    try await session.start(route: route, language: language) { _ in }
    try await session.sendPCM(samples)
    let transcript = try await session.finish()
    try assertEnglishTranscript(transcript)
  }

  private func prepare(_ asset: LocalModelAsset) async throws {
    let backend = FluidAudioLocalModelAssetBackend()
    try await backend.prepare(asset) { _ in }
    let state = await backend.state(of: asset)
    XCTAssertEqual(state, .verified)
  }

  private func requireMatrixAcceptance() throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: "/tmp/timbervox-live-local-matrix"),
      "Touch /tmp/timbervox-live-local-matrix to run the complete local-model matrix."
    )
  }

  private func assertEnglishTranscript(_ transcript: String) throws {
    let normalized = transcript.lowercased()
    XCTAssertTrue(
      normalized.contains("purple") || normalized.contains("elephant"),
      "Unexpected local transcript: \(transcript)"
    )
  }

  private func makeSpeechFixture(
    text: String = "purple elephant marmalade sandwich",
    voice: String? = nil
  ) throws -> URL {
    let output = FileManager.default.temporaryDirectory
      .appendingPathComponent("timbervox-local-acceptance-\(UUID().uuidString).aiff")
    try? FileManager.default.removeItem(at: output)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    process.arguments = (voice.map { ["-v", $0] } ?? []) + ["-o", output.path, text]
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0)
    return output
  }
}

@MainActor
final class LocalWorkflowLiveTests: XCTestCase {
  func testSystemSpeechRunsThroughOfflineRecordToDeliveryWorkflow() async throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: "/tmp/timbervox-live-local-workflow"),
      "Touch /tmp/timbervox-live-local-workflow to run local record-to-delivery acceptance."
    )
    let artifacts = try LiveAudioTest.makeArtifactsDirectory(named: "local-workflow")
    let speechURL = artifacts.appendingPathComponent("system-speech.aiff")
    let phrase = "purple elephant marmalade sandwich"
    let speechDuration = try LiveAudioTest.writeSpokenPhrase(phrase, to: speechURL)
    let defaultsSuite = "TimberVox.LocalWorkflow.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
    defer { defaults.removePersistentDomain(forName: defaultsSuite) }
    let (workflow, transcriptStore) = try makeWorkflow(artifacts: artifacts, defaults: defaults)
    ModelHub.offlineMode = true
    defer { ModelHub.offlineMode = false }

    _ = try await workflow.start(
      callbacks: DictationWorkflowCallbacks(
        onLevel: { _ in },
        onSamples: { _ in },
        onLiveTranscript: { _ in },
        onRealtimeError: { error in XCTFail(error) }
      )
    )
    let player = try AVAudioPlayer(contentsOf: speechURL)
    player.play()
    try await Task.sleep(for: .seconds(speechDuration + 1.5))
    let stoppedResult = try await workflow.stop()
    let result = try XCTUnwrap(stoppedResult)

    XCTAssertTrue(result.rawText.lowercased().contains("elephant"), result.rawText)
    XCTAssertEqual(result.finalText, result.rawText)
    XCTAssertEqual(result.model, "parakeet-tdt-ctc-110m-coreml")
    let persisted = try XCTUnwrap(transcriptStore.recent(limit: 1).first)
    XCTAssertEqual(persisted.text, result.finalText)
    XCTAssertEqual(persisted.modeID, "local-workflow")
    XCTAssertEqual(NSPasteboard.general.string(forType: .string), result.finalText)
    try result.finalText.write(
      to: artifacts.appendingPathComponent("transcript.txt"),
      atomically: true,
      encoding: .utf8
    )
  }

  private func makeWorkflow(
    artifacts: URL,
    defaults: UserDefaults
  ) throws -> (DictationWorkflow, TranscriptStore) {
    let modeStore = ModeStore(defaults: defaults)
    modeStore.modes = [
      DictationMode(
        id: "local-workflow",
        name: "Local Workflow Acceptance",
        audioModelID: "local-hummingbird",
        languageCode: "en",
        realtimeEnabled: false,
        diarizationEnabled: false,
        includesSystemAudio: true,
        playbackPolicy: .keepPlaying,
        textTransformPreset: .voiceToText,
        textTransformModelID: "unused"
      )
    ]
    modeStore.activeModeID = "local-workflow"
    let transcriptStore = TranscriptStore(directory: artifacts)
    let offlineBaseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:1"))
    let cloud = CloudClients(baseURL: offlineBaseURL)
    let catalogStore = TranscriptionModelCatalogStore(
      cloudCatalog: CloudModelCatalogStore(client: cloud.catalog)
    )
    let workflow = DictationWorkflow(
      cloud: cloud,
      transcriptStore: transcriptStore,
      modeStore: modeStore,
      catalogStore: catalogStore,
      localBatchTranscription: LocalBatchTranscriptionClient()
    )
    return (workflow, transcriptStore)
  }
}
