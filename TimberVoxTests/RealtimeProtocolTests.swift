import XCTest

@testable import TimberVox

final class RealtimeProtocolTests: XCTestCase {
  func testParsesProviderNeutralTranscriptEvents() {
    XCTAssertEqual(
      RealtimeEventParser.parse(
        #"{"protocol_version":1,"sequence":2,"session_id":"rt_1","type":"transcript.interim","text":"hello","segments":[],"speaker_turns":[],"words":[]}"#
      ),
      .interimTranscript("hello")
    )
    XCTAssertEqual(
      RealtimeEventParser.parse(
        #"{"protocol_version":1,"sequence":3,"session_id":"rt_1","type":"transcript.delta","text":" world","segments":[],"speaker_turns":[],"words":[]}"#
      ),
      .transcriptDelta(" world")
    )
    XCTAssertEqual(
      RealtimeEventParser.parse(
        #"{"protocol_version":1,"sequence":4,"session_id":"rt_1","type":"transcript.committed","text":"hello world","segments":[{"startSeconds":0.5,"endSeconds":1.2,"text":"hello world"}],"speaker_turns":[],"words":[]}"#
      ),
      .committedTranscript("hello world", start: 0.5)
    )
  }

  func testParsesTerminalSessionEvents() {
    XCTAssertEqual(
      RealtimeEventParser.parse(
        #"{"protocol_version":1,"sequence":5,"session_id":"rt_1","type":"session.completed","status":"succeeded","transcript":"hello world"}"#
      ),
      .sessionCompleted("hello world")
    )
    XCTAssertEqual(
      RealtimeEventParser.parse(
        #"{"protocol_version":1,"sequence":5,"session_id":"rt_1","type":"session.failed","status":"failed","transcript":"","error":{"code":"provider_error","message":"bad audio","retryable":true}}"#
      ),
      .sessionFailed("bad audio")
    )
  }

  func testDoesNotParseProviderNativeEventsAsTranscripts() {
    XCTAssertEqual(
      RealtimeEventParser.parse(
        #"{"type":"Results","channel":{"alternatives":[{"transcript":"raw"}]},"is_final":true}"#
      ),
      .unrecognized(type: "Results")
    )
  }
}
