import Foundation
import PeacockeryVoiceClient

struct TextTransformStreamResult: Equatable, Sendable {
  var events: [APIJSONValue]
  var outcome: TextTransformOutcome
}

extension TextTransformAPIClient {
  func streamTransform(
    request: TextTransformRequest,
    onText: @Sendable (String) -> Void
  ) async throws -> TextTransformStreamResult {
    let requestBody = try sdk.sdkValue(
      request,
      as: Components.Schemas.TextStreamRequest.self
    )
    let output = try await sdk.client().postV1TextStream(
      .init(body: .json(requestBody))
    )
    var stream = TextTransformStreamAccumulator()
    var pending = ""
    switch output {
    case .ok(let response):
      for try await chunk in try response.body.textEventStream {
        guard let text = String(bytes: chunk, encoding: .utf8) else {
          throw stream.error(.invalidEvent("The event stream was not valid UTF-8."))
        }
        pending += text
        while let newline = pending.firstIndex(of: "\n") {
          let line = String(pending[..<newline])
            .trimmingCharacters(in: .whitespacesAndNewlines)
          pending.removeSubrange(...newline)
          if let payload = eventPayload(from: line) {
            try stream.consume(payload: payload, onText: onText)
          }
        }
      }
    case .badRequest:
      throw APIConnectorError.httpStatus(400)
    case .unauthorized:
      throw APIConnectorError.httpStatus(401)
    case .undocumented(let statusCode, _):
      throw APIConnectorError.httpStatus(statusCode)
    }
    if let payload = eventPayload(
      from: pending.trimmingCharacters(in: .whitespacesAndNewlines)
    ) {
      try stream.consume(payload: payload, onText: onText)
    }

    guard let outcome = stream.outcome else {
      throw stream.error(.missingTerminalEvent)
    }
    return TextTransformStreamResult(events: stream.events, outcome: outcome)
  }
}

private func eventPayload(from line: String) -> String? {
  guard line.hasPrefix("data:") else { return nil }
  let payload = String(line.dropFirst("data:".count))
    .trimmingCharacters(in: .whitespaces)
  return payload.isEmpty ? nil : payload
}

private struct TextTransformStreamAccumulator {
  private(set) var events: [APIJSONValue] = []
  private(set) var outcome: TextTransformOutcome?
  private var accumulatedText = ""
  private var expectedSequence = 0
  private var started: TextStreamStarted?

  mutating func consume(
    payload: String,
    onText: @Sendable (String) -> Void
  ) throws {
    guard let data = payload.data(using: .utf8) else {
      events.append(.string(payload))
      throw error(.invalidEvent("The event was not valid UTF-8."))
    }
    appendRawEvent(data: data, payload: payload)
    let envelope = try decode(TextStreamEnvelope.self, from: data)
    guard outcome == nil else { throw error(.eventAfterTerminal) }
    guard envelope.protocolVersion == 1, envelope.sequence == expectedSequence else {
      throw error(.invalidSequence)
    }
    expectedSequence += 1

    switch envelope.type {
    case "stream.started":
      try consumeStart(data: data, sequence: envelope.sequence)
    case "text.delta":
      try consumeDelta(data: data, onText: onText)
    case "stream.completed":
      try consumeCompletion(data: data)
    case "stream.failed":
      try consumeFailure(data: data)
    default:
      throw error(.unknownEvent(envelope.type))
    }
  }

  func error(_ reason: TextTransformStreamFailureReason) -> TextTransformStreamError {
    TextTransformStreamError(events: events, reason: reason)
  }

  private mutating func appendRawEvent(data: Data, payload: String) {
    do {
      events.append(try APIConnectorCoders.decode(APIJSONValue.self, from: data))
    } catch {
      events.append(.string(payload))
    }
  }

  private mutating func consumeStart(data: Data, sequence: Int) throws {
    guard started == nil, sequence == 0 else { throw error(.invalidSequence) }
    started = try decode(TextStreamStarted.self, from: data)
  }

  private mutating func consumeDelta(
    data: Data,
    onText: @Sendable (String) -> Void
  ) throws {
    guard started != nil else { throw error(.missingStart) }
    let event = try decode(TextStreamDelta.self, from: data)
    accumulatedText += event.delta
    onText(accumulatedText)
  }

  private mutating func consumeCompletion(data: Data) throws {
    guard let started else { throw error(.missingStart) }
    let event = try decode(TextStreamCompleted.self, from: data)
    try validateIdentity(event.identity, started: started)
    outcome = TextTransformOutcome(
      finishReason: event.finishReason,
      model: event.model,
      providerLatencyMs: event.providerLatencyMs,
      provider: event.provider,
      performance: event.performance,
      responseModelID: event.responseModelID,
      text: accumulatedText,
      upstreamModel: event.upstreamModel,
      usage: event.usage,
      warnings: event.warnings
    )
  }

  private func consumeFailure(data: Data) throws -> Never {
    guard let started else { throw error(.missingStart) }
    let event = try decode(TextStreamFailed.self, from: data)
    try validateIdentity(event.identity, started: started)
    throw error(
      .provider(
        code: event.error.code,
        message: event.error.message,
        retryable: event.error.retryable
      )
    )
  }

  private func validateIdentity(
    _ identity: TextStreamIdentity,
    started: TextStreamStarted
  ) throws {
    guard identity == started.identity else { throw error(.identityChanged) }
  }

  private func decode<Event: Decodable>(
    _ type: Event.Type,
    from data: Data
  ) throws -> Event {
    do {
      return try APIConnectorCoders.decode(type, from: data)
    } catch {
      throw self.error(.invalidEvent(error.localizedDescription))
    }
  }
}

private struct TextStreamIdentity: Equatable {
  var model: String
  var provider: String
  var upstreamModel: String
}

private struct TextStreamEnvelope: Decodable {
  var protocolVersion: Int
  var sequence: Int
  var type: String
}

private struct TextStreamStarted: Decodable {
  var model: String
  var provider: String
  var upstreamModel: String

  var identity: TextStreamIdentity {
    TextStreamIdentity(model: model, provider: provider, upstreamModel: upstreamModel)
  }
}

private struct TextStreamDelta: Decodable {
  var delta: String
}

private struct TextStreamCompleted: Decodable {
  var finishReason: String
  var model: String
  var performance: TextTransformPerformance
  var provider: String
  var providerLatencyMs: Double
  var responseModelID: String
  var upstreamModel: String
  var usage: TextTransformUsage
  var warnings: [APIJSONValue]

  var identity: TextStreamIdentity {
    TextStreamIdentity(model: model, provider: provider, upstreamModel: upstreamModel)
  }

  private enum CodingKeys: String, CodingKey {
    case finishReason
    case model
    case performance
    case provider
    case providerLatencyMs
    case responseModelID = "responseModelId"
    case upstreamModel
    case usage
    case warnings
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    finishReason = try container.decode(String.self, forKey: .finishReason)
    model = try container.decode(String.self, forKey: .model)
    performance = try container.decode(TextTransformPerformance.self, forKey: .performance)
    provider = try container.decode(String.self, forKey: .provider)
    providerLatencyMs = try container.decode(Double.self, forKey: .providerLatencyMs)
    responseModelID = try container.decode(String.self, forKey: .responseModelID)
    upstreamModel = try container.decode(String.self, forKey: .upstreamModel)
    usage = try container.decode(TextTransformUsage.self, forKey: .usage)
    warnings = try container.decodeIfPresent([APIJSONValue].self, forKey: .warnings) ?? []
  }
}

private struct TextStreamFailed: Decodable {
  struct Failure: Decodable {
    var code: String
    var message: String
    var retryable: Bool
  }

  var error: Failure
  var model: String
  var provider: String
  var upstreamModel: String

  var identity: TextStreamIdentity {
    TextStreamIdentity(model: model, provider: provider, upstreamModel: upstreamModel)
  }
}

enum TextTransformStreamFailureReason: Equatable, Sendable {
  case eventAfterTerminal
  case identityChanged
  case invalidEvent(String)
  case invalidSequence
  case missingStart
  case missingTerminalEvent
  case provider(code: String, message: String, retryable: Bool)
  case unknownEvent(String)
}

struct TextTransformStreamError: LocalizedError, Sendable {
  var events: [APIJSONValue]
  var reason: TextTransformStreamFailureReason

  var code: String {
    switch reason {
    case .eventAfterTerminal: "event_after_terminal"
    case .identityChanged: "identity_changed"
    case .invalidEvent: "invalid_event"
    case .invalidSequence: "invalid_sequence"
    case .missingStart: "missing_start"
    case .missingTerminalEvent: "missing_terminal_event"
    case .provider(let code, _, _): code
    case .unknownEvent: "unknown_event"
    }
  }

  var retryable: Bool {
    guard case .provider(_, _, let retryable) = reason else { return false }
    return retryable
  }

  var errorDescription: String? {
    switch reason {
    case .eventAfterTerminal:
      "Text processing returned an event after it had already finished."
    case .identityChanged:
      "Text processing changed provider or model during one stream."
    case .invalidEvent(let detail):
      "Text processing returned an invalid event: \(detail)"
    case .invalidSequence:
      "Text processing returned events out of sequence."
    case .missingStart:
      "Text processing completed before its start event."
    case .missingTerminalEvent:
      "Text processing ended without a completion or failure event."
    case .provider(_, let message, _):
      message
    case .unknownEvent(let type):
      "Text processing returned an unknown event: \(type)."
    }
  }
}
