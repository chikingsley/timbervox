@preconcurrency import AVFoundation
import FluidAudio
import XCTest

@testable import TimberVox

final class SongbirdLiveAcceptanceTests: XCTestCase {
  private struct Fixture {
    var language: String
    var voice: String
    var text: String
    var expectedStems: [String]
  }

  private let sharedFixtures = [
    Fixture(
      language: "de",
      voice: "Anna",
      text: "Der violette Elefant geht durch den ruhigen Garten.",
      expectedStems: ["elefant", "garten"]
    ),
    Fixture(
      language: "en",
      voice: "Samantha",
      text: "The purple elephant walks through the quiet garden.",
      expectedStems: ["elephant", "garden"]
    ),
    Fixture(
      language: "es",
      voice: "Mónica",
      text: "El elefante morado camina por el jardín tranquilo.",
      expectedStems: ["elefant", "jardin"]
    ),
    Fixture(
      language: "fr",
      voice: "Thomas",
      text: "L'éléphant violet marche dans le jardin tranquille.",
      expectedStems: ["elephant", "jardin"]
    ),
    Fixture(
      language: "it",
      voice: "Alice",
      text: "L'elefante viola cammina nel giardino tranquillo.",
      expectedStems: ["elefant", "giardino"]
    ),
    Fixture(
      language: "pt",
      voice: "Joana",
      text: "O elefante roxo caminha pelo jardim tranquilo.",
      expectedStems: ["elefant", "jardim"]
    ),
  ]

  private let realtimeOnlyFixtures = [
    Fixture(
      language: "ja",
      voice: "Kyoko",
      text: "紫の象が静かな庭を歩いています。",
      expectedStems: []
    ),
    Fixture(
      language: "zh",
      voice: "Tingting",
      text: "紫色的大象走过安静的花园。",
      expectedStems: []
    ),
  ]

  func testSongbirdRunsEveryPublishedSharedAndRealtimeOnlyLanguage() async throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: "/tmp/timbervox-live-songbird"),
      "Touch /tmp/timbervox-live-songbird to run real Songbird language acceptance."
    )
    let artifacts = try LiveAudioTest.makeArtifactsDirectory(named: "songbird-languages")
    let batch = LocalBatchTranscriptionClient.shared
    let realtime = LocalRealtimeTranscriptionSession.shared
    let backend = FluidAudioLocalModelAssetBackend()
    try await backend.prepare(.batch(.parakeetTdtV3)) { _ in }
    ModelHub.offlineMode = true
    defer { ModelHub.offlineMode = false }

    for fixture in sharedFixtures {
      let audio = try makeSpeechFixture(fixture, artifacts: artifacts)
      let batchText = try await batch.transcribe(wavAt: audio, route: .parakeetTdtV3)
      try assertTranscript(batchText, fixture: fixture, transport: "batch")
    }

    for fixture in sharedFixtures + realtimeOnlyFixtures {
      let audio = try makeSpeechFixture(fixture, artifacts: artifacts)
      let samples = try AudioConverter().resampleAudioFile(audio)
      try await realtime.start(
        route: .nemotronMultilingual1120,
        language: fixture.language
      ) { _ in }
      try await realtime.sendPCM(samples)
      let realtimeText = try await realtime.finish()
      try assertTranscript(realtimeText, fixture: fixture, transport: "realtime")
    }

    let metrics = try storageMetrics()
    let data = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: artifacts.appendingPathComponent("storage-bytes.json"), options: .atomic)
    XCTAssertGreaterThan(metrics["parakeetV3"] ?? 0, 0)
    XCTAssertGreaterThan(metrics["nemotronLatin"] ?? 0, 0)
    XCTAssertGreaterThan(metrics["nemotronFull"] ?? 0, 0)
  }

  private func makeSpeechFixture(_ fixture: Fixture, artifacts: URL) throws -> URL {
    let output = artifacts.appendingPathComponent("\(fixture.language).aiff")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    process.arguments = ["-v", fixture.voice, "-o", output.path, fixture.text]
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0, fixture.language)
    return output
  }

  private func assertTranscript(
    _ transcript: String,
    fixture: Fixture,
    transport: String
  ) throws {
    let normalized = transcript.folding(
      options: [.diacriticInsensitive, .caseInsensitive],
      locale: .current
    )
    XCTAssertFalse(normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    if !fixture.expectedStems.isEmpty {
      XCTAssertTrue(
        fixture.expectedStems.contains { normalized.contains($0) },
        "\(fixture.language) \(transport) transcript: \(transcript)"
      )
    }
  }

  private func storageMetrics() throws -> [String: Int] {
    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FluidAudio/Models", isDirectory: true)
    return [
      "parakeetV3": try recursiveFileSize(
        AsrModels.defaultCacheDirectory(for: .v3)
      ),
      "nemotronLatin": try recursiveFileSize(
        root.appendingPathComponent("nemotron-multilingual/latin/1120ms", isDirectory: true)
      ),
      "nemotronFull": try recursiveFileSize(
        root.appendingPathComponent("nemotron-multilingual/multilingual/1120ms", isDirectory: true)
      ),
    ]
  }

  private func recursiveFileSize(_ directory: URL) throws -> Int {
    let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
    guard
      let files = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: keys
      )
    else { return 0 }
    var total = 0
    for case let file as URL in files {
      let values = try file.resourceValues(forKeys: Set(keys))
      let isRegularFile = values.isRegularFile ?? false
      if isRegularFile {
        total += values.fileSize ?? 0
      }
    }
    return total
  }
}
