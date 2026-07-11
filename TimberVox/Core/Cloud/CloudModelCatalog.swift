import Foundation

enum CloudModelKind: String, Decodable, Sendable {
  case language
  case transcription
}

struct CloudModelRouteSpec: Decodable, Equatable, Sendable {
  var model: String
  var provider: String
  var supportedLanguages: [String]
  var supportsAutomaticLanguage: Bool
  var supportsDiarization: Bool
  var upstreamModel: String
}

extension CloudModelRouteSpec {
  private enum CodingKeys: String, CodingKey {
    case model
    case provider
    case supportedLanguages
    case supportsAutomaticLanguage
    case supportsDiarization
    case upstreamModel
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    model = try container.decode(String.self, forKey: .model)
    provider = try container.decode(String.self, forKey: .provider)
    supportedLanguages = try container.decode([String].self, forKey: .supportedLanguages)
    supportsAutomaticLanguage =
      try container.decodeIfPresent(Bool.self, forKey: .supportsAutomaticLanguage) ?? false
    supportsDiarization = try container.decode(Bool.self, forKey: .supportsDiarization)
    upstreamModel = try container.decode(String.self, forKey: .upstreamModel)
  }
}

struct CloudModelRoutes: Decodable, Equatable, Sendable {
  var batch: CloudModelRouteSpec?
  var realtime: CloudModelRouteSpec?
}

struct CloudModelSpec: Decodable, Equatable, Identifiable, Sendable {
  var id: String
  var kind: CloudModelKind
  var provider: String
  var routes: CloudModelRoutes?
  var upstreamModel: String

  var supportsBatch: Bool {
    kind == .transcription && batchRoute != nil
  }

  var supportsRealtime: Bool {
    kind == .transcription && realtimeRoute != nil
  }

  var isBatchTranscription: Bool { supportsBatch }

  var isRealtimeTranscription: Bool { supportsRealtime }

  var isLanguageModel: Bool {
    kind == .language
  }

  var displayName: String {
    let prefix = "\(provider)-"
    let rawName = id.hasPrefix(prefix) ? String(id.dropFirst(prefix.count)) : id
    return
      rawName
      .replacingOccurrences(of: "/", with: " / ")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .capitalized
  }

  var menuLabel: String {
    "\(displayName) (\(provider.capitalized))"
  }

  var batchRoute: CloudModelRouteSpec? {
    routes?.batch
  }

  var realtimeRoute: CloudModelRouteSpec? {
    routes?.realtime
  }
}
