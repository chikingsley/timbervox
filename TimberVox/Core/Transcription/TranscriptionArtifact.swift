import Foundation

enum TranscriptionDataAvailability: String, Codable, Equatable, Sendable {
  case available
  case notRequested = "not_requested"
  case providerOmitted = "provider_omitted"
  case unsupported
}

enum TranscriptionDataSource: String, Codable, Equatable, Sendable {
  case derived
  case provider
}

struct TranscriptionCollection<Item: Codable & Equatable & Sendable>:
  Codable, Equatable, Sendable
{
  var availability: TranscriptionDataAvailability
  var source: TranscriptionDataSource?
  var items: [Item]
}

enum TranscriptionSpeaker: Codable, Equatable, Sendable {
  case number(Double)
  case text(String)

  var label: String {
    switch self {
    case .number(let value): value.formatted()
    case .text(let value): value
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let value = try? container.decode(String.self) {
      self = .text(value)
    } else {
      self = try .number(container.decode(Double.self))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .number(let value): try container.encode(value)
    case .text(let value): try container.encode(value)
    }
  }
}

struct TranscriptionScores: Codable, Equatable, Sendable {
  var confidence: Double?
  var logProbability: Double?
  var probability: Double?
  var score: Double?
  var speakerConfidence: Double?
}

struct TranscriptionTimedText: Codable, Equatable, Sendable {
  var endSeconds: Double
  var scores: TranscriptionScores?
  var speaker: TranscriptionSpeaker?
  var startSeconds: Double
  var text: String
}

struct TranscriptionToken: Codable, Equatable, Sendable {
  var endSeconds: Double?
  var kind: String?
  var scores: TranscriptionScores?
  var speaker: TranscriptionSpeaker?
  var startSeconds: Double?
  var text: String
  var tokenID: Int?

  private enum CodingKeys: String, CodingKey {
    case endSeconds
    case kind
    case scores
    case speaker
    case startSeconds
    case text
    case tokenID = "tokenId"
  }
}

struct TranscriptionAudioEvent: Codable, Equatable, Sendable {
  var endSeconds: Double?
  var startSeconds: Double?
  var text: String
}

struct TranscriptionContent: Codable, Equatable, Sendable {
  var audioEvents: TranscriptionCollection<TranscriptionAudioEvent>
  var segments: TranscriptionCollection<TranscriptionTimedText>
  var speakerTurns: TranscriptionCollection<TranscriptionTimedText>
  var tokens: TranscriptionCollection<TranscriptionToken>
  var words: TranscriptionCollection<TranscriptionTimedText>
}

struct TranscriptionLanguage: Codable, Equatable, Sendable {
  var confidence: Double?
  var detected: String?
  var requested: String?
}

struct TranscriptionUsage: Codable, Equatable, Sendable {
  var inputTokens: Int?
  var outputTokens: Int?
  var totalTokens: Int?
}

struct TranscriptionMetrics: Codable, Equatable, Sendable {
  var audioDurationSeconds: Double?
  var decoderSeconds: Double?
  var encoderSeconds: Double?
  var firstResultLatencyMs: Double?
  var gpuUtilization: Double?
  var normalizationLatencyMs: Double?
  var peakMemoryMB: Double?
  var preprocessorSeconds: Double?
  var processingSeconds: Double?
  var providerLatencyMs: Double?
  var queueDelayMs: Double?
  /// Audio duration divided by processing duration. Higher is faster.
  var realtimeSpeedFactor: Double?
  var tokensPerSecond: Double?
  var usage: TranscriptionUsage
  var wallLatencyMs: Double?
}

enum TranscriptionExecutor: String, Codable, Equatable, Sendable {
  case cloud
  case local
}

enum TranscriptionTransport: String, Codable, Equatable, Sendable {
  case batch
  case realtime
}

struct TranscriptionProvenance: Codable, Equatable, Sendable {
  var completedAt: Date
  var executor: TranscriptionExecutor
  var libraryName: String?
  var libraryVersion: String?
  var model: String
  var provider: String
  var providerRequestID: String?
  var runID: String
  var startedAt: Date
  var transport: TranscriptionTransport
  var upstreamModel: String

  private enum CodingKeys: String, CodingKey {
    case completedAt
    case executor
    case libraryName
    case libraryVersion
    case model
    case provider
    case providerRequestID = "providerRequestId"
    case runID = "runId"
    case startedAt
    case transport
    case upstreamModel
  }
}

struct TranscriptionProviderResponse: Codable, Equatable, Sendable {
  var mediaType: String
  var payload: [String: TranscriptionJSONValue]
}

struct TranscriptionProviderCapture: Codable, Equatable, Sendable {
  var metadata: [String: TranscriptionJSONValue]
  var response: TranscriptionProviderResponse
}

struct TranscriptionWarning: Codable, Equatable, Sendable {
  var code: String
  var message: String
}

enum TranscriptionSchemaVersion: Int, Codable, Equatable, Sendable {
  case version1 = 1
  case version2 = 2
}

struct TranscriptionArtifact: Codable, Equatable, Sendable {
  static let currentSchemaVersion = TranscriptionSchemaVersion.version2

  var content: TranscriptionContent
  var language: TranscriptionLanguage
  var metrics: TranscriptionMetrics
  var provenance: TranscriptionProvenance
  var providerCapture: TranscriptionProviderCapture
  var schemaVersion: TranscriptionSchemaVersion
  var text: String
  var warnings: [TranscriptionWarning]

  var displayText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

enum TranscriptionArtifactCoders {
  static func encode(_ artifact: TranscriptionArtifact) throws -> Data {
    try TimberVoxJSONCoding.makeEncoder().encode(artifact)
  }

  static func decode(_ data: Data) throws -> TranscriptionArtifact {
    try TimberVoxJSONCoding.makeDecoder().decode(TranscriptionArtifact.self, from: data)
  }
}

enum TranscriptionJSONValue: Codable, Equatable, Sendable {
  case array([TranscriptionJSONValue])
  case bool(Bool)
  case null
  case number(Double)
  case object([String: TranscriptionJSONValue])
  case string(String)

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([TranscriptionJSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: TranscriptionJSONValue].self))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .array(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .null: try container.encodeNil()
    case .number(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    }
  }
}
