import Foundation

enum TextTransformationSchemaVersion: Int, Codable, Equatable, Sendable {
  case version1 = 1
  case version2 = 2
  case version3 = 3
}

struct TextTransformationFailure: Codable, Equatable, Sendable {
  var code: String
  var message: String
  var retryable: Bool

  init(error: Error) {
    if let streamError = error as? TextTransformStreamError {
      code = streamError.code
      message = streamError.localizedDescription
      retryable = streamError.retryable
    } else if let apiError = error as? APIConnectorError {
      switch apiError {
      case .httpStatus(let status):
        code = "http_\(status)"
      case .configuration:
        code = "configuration"
      case .invalidResponse:
        code = "invalid_response"
      }
      message = error.localizedDescription
      retryable = apiError.isTransientHTTPFailure
    } else if let urlError = error as? URLError {
      code = "url_\(urlError.errorCode)"
      message = urlError.localizedDescription
      retryable = true
    } else {
      code = "text_processing"
      message = error.localizedDescription
      retryable = false
    }
  }
}

/// The request, response, and timing retained alongside one dictation record.
/// This is an embedded capture, not a separately identified domain artifact.
struct TextTransformationCapture: Codable, Equatable, Sendable {
  static let currentSchemaVersion = TextTransformationSchemaVersion.version3

  var completedAt: Date
  var failure: TextTransformationFailure?
  var outcome: TextTransformOutcome?
  var request: TextTransformRequest
  var schemaVersion: TextTransformationSchemaVersion
  var startedAt: Date
  var streamEvents: [APIJSONValue]
  var wallLatencyMs: Double

  init(
    completedAt: Date,
    failure: TextTransformationFailure? = nil,
    outcome: TextTransformOutcome?,
    request: TextTransformRequest,
    schemaVersion: TextTransformationSchemaVersion,
    startedAt: Date,
    streamEvents: [APIJSONValue] = [],
    wallLatencyMs: Double
  ) {
    self.completedAt = completedAt
    self.failure = failure
    self.outcome = outcome
    self.request = request
    self.schemaVersion = schemaVersion
    self.startedAt = startedAt
    self.streamEvents = streamEvents
    self.wallLatencyMs = wallLatencyMs
  }

  private enum CodingKeys: String, CodingKey {
    case completedAt
    case failure
    case outcome
    case request
    case schemaVersion
    case startedAt
    case streamEvents
    case wallLatencyMs
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    completedAt = try container.decode(Date.self, forKey: .completedAt)
    failure = try container.decodeIfPresent(TextTransformationFailure.self, forKey: .failure)
    outcome = try container.decodeIfPresent(TextTransformOutcome.self, forKey: .outcome)
    request = try container.decode(TextTransformRequest.self, forKey: .request)
    schemaVersion = try container.decode(TextTransformationSchemaVersion.self, forKey: .schemaVersion)
    startedAt = try container.decode(Date.self, forKey: .startedAt)
    streamEvents = try container.decodeIfPresent([APIJSONValue].self, forKey: .streamEvents) ?? []
    wallLatencyMs = try container.decode(Double.self, forKey: .wallLatencyMs)
  }
}

enum TextTransformationCaptureCoders {
  static func encode(_ capture: TextTransformationCapture) throws -> Data {
    try TimberVoxJSONCoding.makeEncoder().encode(capture)
  }

  static func decode(_ data: Data) throws -> TextTransformationCapture {
    try TimberVoxJSONCoding.makeDecoder().decode(TextTransformationCapture.self, from: data)
  }
}
