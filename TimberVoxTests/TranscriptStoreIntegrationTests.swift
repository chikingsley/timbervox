import XCTest

@testable import TimberVox

/// Uses a real temporary SQLite database through the production GRDB store.
final class TranscriptStoreIntegrationTests: XCTestCase {
  func testRealDatabaseSaveSearchAndDeleteRoundTrip() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("TimberVoxIntegration-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = TranscriptStore(directory: directory)
    let transformation = Self.transformation

    let saved = try store.save(
      text: "A searchable TimberVox transcript",
      artifact: TestTranscriptionArtifact.make(
        text: "A searchable TimberVox transcript",
        model: "integration-model",
        segments: [
          TranscriptionTimedText(
            endSeconds: 0.75,
            scores: nil,
            speaker: .text("1"),
            startSeconds: 0,
            text: "A searchable"
          ),
          TranscriptionTimedText(
            endSeconds: 1.25,
            scores: nil,
            speaker: .text("2"),
            startSeconds: 0.75,
            text: "TimberVox transcript"
          ),
        ]
      ),
      duration: 1.25,
      audioPath: nil,
      transformPreset: "message",
      transformModel: "openai-gpt-5.4-mini",
      transformation: transformation,
      sourceApplicationName: "Notes",
      sourceApplicationBundleIdentifier: "com.apple.Notes"
    )

    let recent = try store.recent()
    XCTAssertEqual(recent.map(\.text), [saved.text])
    XCTAssertEqual(recent.first?.artifact?.content.segments.items.count, 2)
    XCTAssertEqual(recent.first?.artifact?.content.segments.items.last?.speaker, .text("2"))
    XCTAssertEqual(recent.first?.artifact, saved.artifact)
    XCTAssertEqual(recent.first?.transformation, transformation)
    XCTAssertEqual(recent.first?.sourceApplicationName, "Notes")
    XCTAssertEqual(recent.first?.sourceApplicationBundleIdentifier, "com.apple.Notes")
    XCTAssertEqual(try store.search("searchable").map(\.text), [saved.text])

    let savedID = try XCTUnwrap(saved.id)
    try store.delete(id: savedID)
    XCTAssertTrue(try store.recent().isEmpty)
  }

  func testRealDatabaseSupportsPagedHistoryAndCounts() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("TimberVoxPagination-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = TranscriptStore(directory: directory)

    for text in ["first matching transcript", "second matching transcript", "unrelated"] {
      try store.save(
        text: text,
        artifact: TestTranscriptionArtifact.make(text: text),
        duration: 1,
        audioPath: nil
      )
    }

    XCTAssertEqual(try store.count(), 3)
    XCTAssertEqual(try store.count(matching: "matching"), 2)
    XCTAssertEqual(try store.recent(limit: 2).count, 2)
    XCTAssertEqual(try store.recent(limit: 2, offset: 2).count, 1)
    XCTAssertEqual(try store.search("matching", limit: 1).count, 1)
    XCTAssertEqual(try store.search("matching", limit: 1, offset: 1).count, 1)
  }

  private static var transformation: TextTransformationCapture {
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    return TextTransformationCapture(
      completedAt: startedAt.addingTimeInterval(0.25),
      outcome: TextTransformOutcome(
        finishReason: "stop",
        model: "openai-gpt-5.4-mini",
        providerLatencyMs: 200,
        provider: "openai",
        text: "Processed transcript",
        upstreamModel: "gpt-5.4-mini",
        usage: TextTransformUsage(inputTokens: 10, outputTokens: 4, totalTokens: 14),
        warnings: []
      ),
      request: TextTransformRequest(
        messages: [TextTransformMessage(content: "Process this", role: .user)],
        model: "openai-gpt-5.4-mini"
      ),
      schemaVersion: TextTransformationCapture.currentSchemaVersion,
      startedAt: startedAt,
      wallLatencyMs: 250
    )
  }
}
