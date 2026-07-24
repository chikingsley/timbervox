import XCTest

@testable import TimberVox

final class HistoryPresentationPolicyTests: XCTestCase {
  func testLongTranscriptsOpenInDetail() {
    XCTAssertFalse(
      HistoryPresentationPolicy.shouldOpenInDetail(record(textLength: 1_200))
    )
    XCTAssertTrue(
      HistoryPresentationPolicy.shouldOpenInDetail(record(textLength: 1_201))
    )
  }

  func testArtifactModesReflectAvailableRawTimedAndProcessedData() throws {
    var record = record(textLength: 12)
    record.rawText = "raw words"
    record.transcriptionArtifactJSON = try artifactJSON(
      TestTranscriptionArtifact.make(
        text: "raw words",
        words: [
          TranscriptionTimedText(
            endSeconds: 0.5,
            scores: nil,
            speaker: nil,
            startSeconds: 0,
            text: "raw"
          )
        ]
      )
    )

    XCTAssertEqual(record.rawTranscriptText, "raw words")
    XCTAssertEqual(record.defaultTranscriptMode, .processed)
    XCTAssertEqual(record.availableTranscriptModes, [.raw, .segmented, .processed])
  }

  func testUnprocessedTimedArtifactExposesOnlyRawAndSegmentedModes() throws {
    var record = record(textLength: 12)
    record.transcriptionArtifactJSON = try artifactJSON(
      TestTranscriptionArtifact.make(
        text: "raw words",
        words: [
          TranscriptionTimedText(
            endSeconds: 0.5,
            scores: nil,
            speaker: nil,
            startSeconds: 0,
            text: "raw"
          )
        ]
      )
    )

    XCTAssertFalse(record.hasProcessedTranscript)
    XCTAssertEqual(record.availableTranscriptModes, [.raw, .segmented])
  }

  private func record(textLength: Int) -> TranscriptRecord {
    TranscriptRecord(
      id: nil,
      text: String(repeating: "a", count: textLength),
      rawText: nil,
      createdAt: .now,
      durationSeconds: 1,
      model: "test",
      modeID: nil,
      modeName: nil,
      audioPath: nil,
      provider: nil,
      status: .succeeded,
      errorCode: nil,
      errorMessage: nil,
      wallLatencyMs: nil,
      legacyProviderLatencyMs: nil,
      language: nil,
      transformPreset: nil,
      transformModel: nil,
      transformationJSON: nil,
      transcriptionArtifactJSON: nil,
      contextSnapshotJSON: nil,
      legacySegmentsJSON: nil,
      sourceApplicationName: nil,
      sourceApplicationBundleIdentifier: nil,
      importSource: nil,
      importExternalID: nil
    )
  }

  private func artifactJSON(_ artifact: TranscriptionArtifact) throws -> String {
    let data = try TranscriptionArtifactCoders.encode(artifact)
    return try XCTUnwrap(String(data: data, encoding: .utf8))
  }
}
