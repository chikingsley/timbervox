import XCTest

@testable import TimberVox

final class RealtimeProtocolTests: XCTestCase {
  func testParsesSessionReadinessAndAudioAcknowledgementEvents() throws {
    let started = try RealtimeEventParser.parse(
      #"{"protocol_version":1,"sequence":1,"session_id":"rt_1","language":null,"model":"mistral-voxtral-mini-transcribe-realtime-2602","type":"session.started"}"#
    )
    guard case .sessionStarted(let sessionID, _) = started else {
      return XCTFail("Expected a session.started event.")
    }
    XCTAssertEqual(sessionID, "rt_1")

    let acknowledged = try RealtimeEventParser.parse(
      #"{"audio_bytes":5120,"chunk_bytes":5120,"message_count":1,"session_id":"rt_1","type":"audio.received"}"#
    )
    guard case .audioReceived(let totalBytes, _) = acknowledged else {
      return XCTFail("Expected an audio.received event.")
    }
    XCTAssertEqual(totalBytes, 5_120)
  }

  func testParsesProviderNeutralTranscriptEvents() throws {
    let interim = try RealtimeEventParser.parse(
      #"{"protocol_version":1,"sequence":2,"session_id":"rt_1","type":"transcript.interim","text":"hello","segments":[],"speaker_turns":[],"words":[]}"#
    )
    guard case .interimTranscript(let interimPayload) = interim else {
      return XCTFail("Expected an interim transcript.")
    }
    XCTAssertEqual(interimPayload.text, "hello")

    let delta = try RealtimeEventParser.parse(
      #"{"protocol_version":1,"sequence":3,"session_id":"rt_1","type":"transcript.delta","text":" world","segments":[],"speaker_turns":[],"words":[]}"#
    )
    guard case .transcriptDelta(let deltaPayload) = delta else {
      return XCTFail("Expected a transcript delta.")
    }
    XCTAssertEqual(deltaPayload.text, " world")

    let committed = try RealtimeEventParser.parse(
      #"{"protocol_version":1,"sequence":4,"session_id":"rt_1","type":"transcript.committed","text":"hello world","segments":[{"startSeconds":0.5,"endSeconds":1.2,"text":"hello world"}],"speaker_turns":[],"words":[]}"#
    )
    guard case .committedTranscript(let committedPayload) = committed else {
      return XCTFail("Expected a committed transcript.")
    }
    XCTAssertEqual(committedPayload.text, "hello world")
    XCTAssertEqual(committedPayload.segments.first?.startSeconds, 0.5)
  }

  func testParsesCanonicalTerminalArtifacts() throws {
    let artifact = TestTranscriptionArtifact.make(text: "hello world")
    let completed = try RealtimeEventParser.parse(
      terminalJSON(type: "session.completed", status: "succeeded", artifact: artifact)
    )
    XCTAssertEqual(completed, .sessionCompleted(artifact))

    let failed = try RealtimeEventParser.parse(
      terminalJSON(
        type: "session.failed",
        status: "failed",
        artifact: artifact,
        error: [
          "code": "provider_error",
          "message": "bad audio",
          "retryable": true,
        ]
      )
    )
    XCTAssertEqual(failed, .sessionFailed(message: "bad audio", artifact: artifact))
  }

  func testRejectsUnsupportedArtifactSchemaVersion() throws {
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(
        with: TranscriptionArtifactCoders.encode(TestTranscriptionArtifact.make())
      ) as? [String: Any]
    )
    object["schema_version"] = TranscriptionArtifact.currentSchemaVersion.rawValue + 1
    let data = try JSONSerialization.data(withJSONObject: object)

    XCTAssertThrowsError(try TranscriptionArtifactCoders.decode(data))
  }

  func testDoesNotParseProviderNativeEventsAsTranscripts() throws {
    XCTAssertEqual(
      try RealtimeEventParser.parse(
        #"{"type":"Results","channel":{"alternatives":[{"transcript":"raw"}]},"is_final":true}"#
      ),
      .unrecognized(type: "Results")
    )
  }

  func testRejectsMalformedKnownEventsInsteadOfDefaultingFields() {
    XCTAssertThrowsError(
      try RealtimeEventParser.parse(
        #"{"type":"session.started"}"#
      )
    )
    XCTAssertThrowsError(
      try RealtimeEventParser.parse(
        #"{"sequence":2,"type":"transcript.interim","segments":[],"speaker_turns":[],"words":[]}"#
      )
    )
  }

  private func terminalJSON(
    type: String,
    status: String,
    artifact: TranscriptionArtifact,
    error: [String: Any] = [:]
  ) throws -> String {
    var object: [String: Any] = [
      "protocol_version": 1,
      "result": try JSONSerialization.jsonObject(
        with: TranscriptionArtifactCoders.encode(artifact)
      ),
      "sequence": 5,
      "session_id": "rt_1",
      "status": status,
      "type": type,
    ]
    if !error.isEmpty {
      object["error"] = error
    }
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return try XCTUnwrap(String(data: data, encoding: .utf8))
  }
}
