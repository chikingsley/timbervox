import Foundation
import PeacockeryVoiceClient

struct TextTransformMessage: Codable, Equatable, Sendable {
  enum Role: String, Codable, Sendable {
    case assistant
    case system
    case user
  }

  var content: String
  var role: Role

  init(content: String, role: Role) {
    self.content = content
    self.role = role
  }

  init(_ message: TextMessage) {
    content = message.content
    switch message.role {
    case .assistant:
      role = .assistant
    case .system:
      role = .system
    case .user:
      role = .user
    }
  }
}

struct TextTransformOutcome: Codable, Equatable, Sendable {
  var finishReason: String
  var model: String
  var providerLatencyMs: Double?
  var provider: String
  var performance: TextTransformPerformance?
  var responseModelID: String?
  var text: String
  var upstreamModel: String
  var usage: TextTransformUsage
  var warnings: [APIJSONValue]

  private enum CodingKeys: String, CodingKey {
    case finishReason
    case model
    case provider
    case performance
    case providerLatencyMs
    case responseModelID = "responseModelId"
    case text
    case upstreamModel
    case usage
    case warnings
  }

  init(
    finishReason: String,
    model: String,
    providerLatencyMs: Double?,
    provider: String,
    performance: TextTransformPerformance? = nil,
    responseModelID: String? = nil,
    text: String,
    upstreamModel: String,
    usage: TextTransformUsage,
    warnings: [APIJSONValue] = []
  ) {
    self.finishReason = finishReason
    self.model = model
    self.providerLatencyMs = providerLatencyMs
    self.provider = provider
    self.performance = performance
    self.responseModelID = responseModelID
    self.text = text
    self.upstreamModel = upstreamModel
    self.usage = usage
    self.warnings = warnings
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    finishReason = try container.decode(String.self, forKey: .finishReason)
    model = try container.decode(String.self, forKey: .model)
    providerLatencyMs = try container.decodeIfPresent(Double.self, forKey: .providerLatencyMs)
    provider = try container.decode(String.self, forKey: .provider)
    performance = try container.decodeIfPresent(TextTransformPerformance.self, forKey: .performance)
    text = try container.decode(String.self, forKey: .text)
    responseModelID = try container.decodeIfPresent(String.self, forKey: .responseModelID)
    upstreamModel = try container.decode(String.self, forKey: .upstreamModel)
    usage = try container.decode(TextTransformUsage.self, forKey: .usage)
    warnings = try container.decodeIfPresent([APIJSONValue].self, forKey: .warnings) ?? []
  }
}

struct TextTransformUsage: Codable, Equatable, Sendable {
  var inputTokens: Int?
  var outputTokens: Int?
  var reasoningTokens: Int?
  var textTokens: Int?
  var totalTokens: Int?

  init(
    inputTokens: Int?,
    outputTokens: Int?,
    totalTokens: Int?,
    reasoningTokens: Int? = nil,
    textTokens: Int? = nil
  ) {
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.reasoningTokens = reasoningTokens
    self.textTokens = textTokens
    self.totalTokens = totalTokens
  }
}

struct TextTransformPerformance: Codable, Equatable, Sendable {
  var effectiveOutputTokensPerSecond: Double
  var outputTokensPerSecond: Double?
  var responseTimeMs: Double
  var stepTimeMs: Double
  var timeToFirstOutputMs: Double?
}

struct TextTransformRequest: Codable, Equatable, Sendable {
  var messages: [TextTransformMessage]
  var model: String
  var providerOptions: [String: [String: APIJSONValue]]
  var temperature: Double?

  init(
    messages: [TextTransformMessage],
    model: String,
    providerOptions: [String: [String: APIJSONValue]] = [:],
    temperature: Double? = nil
  ) {
    self.messages = messages
    self.model = model
    self.providerOptions = providerOptions
    self.temperature = temperature
  }
}

struct TextTransformAPIClient: Sendable {
  static let current = TextTransformAPIClient(baseURL: APIConnector.defaultBaseURL)

  var sdk: PeacockeryVoiceSDK

  init(baseURL: URL) {
    sdk = PeacockeryVoiceSDK(baseURL: baseURL)
  }

  /// One-shot v1/text call. The app streams via `streamTransform`; this stays
  /// as the live-acceptance probe for the deployed one-shot endpoint.
  func transform(request: TextTransformRequest) async throws -> TextTransformOutcome {
    let body = try sdk.sdkValue(request, as: Components.Schemas.TextRequest.self)
    let output = try await sdk.client().postV1Text(.init(body: .json(body)))
    let payload: Components.Schemas.TextResponse
    switch output {
    case .ok(let response):
      payload = try response.body.json
    case .badRequest:
      throw APIConnectorError.httpStatus(400)
    case .unauthorized:
      throw APIConnectorError.httpStatus(401)
    case .undocumented(let statusCode, _):
      throw APIConnectorError.httpStatus(statusCode)
    }
    return try sdk.localValue(payload, as: TextTransformOutcome.self)
  }
}
