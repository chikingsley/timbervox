import Foundation

enum RealtimeEventParser {
  static func parse(_ text: String) throws -> CloudRealtimeTranscriptionEvent {
    guard let data = text.data(using: .utf8) else {
      throw CloudRealtimeClientError.malformedEvent("message is not UTF-8")
    }
    let eventType = try decode(EventTypeEnvelope.self, from: data).type

    switch eventType {
    case "session.started":
      let envelope = try decode(SessionStartedEnvelope.self, from: data)
      guard !envelope.sessionID.isEmpty else {
        throw CloudRealtimeClientError.malformedEvent("session.started has an empty session_id")
      }
      return .sessionStarted(
        sessionID: envelope.sessionID,
        rawPayload: try rawPayload(from: data)
      )
    case "audio.received":
      let envelope = try decode(AudioReceivedEnvelope.self, from: data)
      return .audioReceived(
        totalBytes: envelope.audioBytes,
        rawPayload: try rawPayload(from: data)
      )
    case "transcript.interim":
      return .interimTranscript(try transcriptPayload(from: data))
    case "transcript.delta":
      return .transcriptDelta(try transcriptPayload(from: data))
    case "transcript.committed":
      return .committedTranscript(try transcriptPayload(from: data))
    case "session.completed":
      return .sessionCompleted(try decode(TerminalEnvelope.self, from: data).result)
    case "session.failed":
      let envelope = try decode(FailedTerminalEnvelope.self, from: data)
      return .sessionFailed(
        message: envelope.error.message,
        artifact: envelope.result
      )
    default:
      return .unrecognized(type: eventType)
    }
  }

  private static func transcriptPayload(from data: Data) throws -> CloudRealtimeTranscriptPayload {
    let envelope = try decode(TranscriptEnvelope.self, from: data)
    return CloudRealtimeTranscriptPayload(
      rawPayload: try rawPayload(from: data),
      segments: envelope.segments,
      sequence: envelope.sequence,
      speakerTurns: envelope.speakerTurns,
      speechFinal: envelope.speechFinal,
      text: envelope.text,
      words: envelope.words
    )
  }

  private static func rawPayload(
    from data: Data
  ) throws -> [String: TranscriptionJSONValue] {
    try decode([String: TranscriptionJSONValue].self, from: data)
  }

  private static func decode<Value: Decodable>(
    _ type: Value.Type,
    from data: Data
  ) throws -> Value {
    do {
      return try TimberVoxJSONCoding.makeDecoder().decode(type, from: data)
    } catch {
      throw CloudRealtimeClientError.malformedEvent(error.localizedDescription)
    }
  }

  private struct AudioReceivedEnvelope: Decodable {
    var audioBytes: Int
  }

  private struct EventTypeEnvelope: Decodable {
    var type: String
  }

  private struct FailedTerminalEnvelope: Decodable {
    struct Failure: Decodable {
      var message: String
    }

    var error: Failure
    var result: TranscriptionArtifact
  }

  private struct SessionStartedEnvelope: Decodable {
    var sessionID: String

    private enum CodingKeys: String, CodingKey {
      case sessionID = "sessionId"
    }
  }

  private struct TerminalEnvelope: Decodable {
    var result: TranscriptionArtifact
  }

  private struct TranscriptEnvelope: Decodable {
    var segments: [TranscriptionTimedText]
    var sequence: Int
    var speakerTurns: [TranscriptionTimedText]
    var speechFinal: Bool
    var text: String
    var words: [TranscriptionTimedText]

    private enum CodingKeys: String, CodingKey {
      case segments
      case sequence
      case speakerTurns
      case speechFinal
      case text
      case words
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      segments = try container.decode([TranscriptionTimedText].self, forKey: .segments)
      sequence = try container.decode(Int.self, forKey: .sequence)
      speakerTurns = try container.decode([TranscriptionTimedText].self, forKey: .speakerTurns)
      speechFinal = try container.decodeIfPresent(Bool.self, forKey: .speechFinal) ?? false
      text = try container.decode(String.self, forKey: .text)
      words = try container.decode([TranscriptionTimedText].self, forKey: .words)
    }
  }
}

enum RealtimeRecoveryResult {
  static func event(from data: Data) throws -> CloudRealtimeTranscriptionEvent {
    guard let text = String(data: data, encoding: .utf8) else {
      throw URLError(.cannotParseResponse)
    }
    let event = try RealtimeEventParser.parse(text)
    switch event {
    case .sessionCompleted, .sessionFailed:
      return event
    default:
      throw URLError(.cannotParseResponse)
    }
  }
}
