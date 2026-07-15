import Foundation

enum CatalogModelKind: String, Decodable, Sendable {
  case language
  case transcription
}

enum CatalogModelSpeedKind: String, Decodable, Equatable, Sendable {
  case effectiveTPS = "effective-tps"
  case realtime
  case rtfx
}

struct CatalogModelAccuracy: Decodable, Equatable, Sendable {
  var benchmark: String
  var metric: String
  var source: String
  var value: Double

  var label: String {
    guard metric == "wer" else { return value.formatted() }
    return value.formatted(.number.precision(.fractionLength(0...2))) + "% WER"
  }
}

struct CatalogModelSpeed: Decodable, Equatable, Sendable {
  var approximate: Bool
  var kind: CatalogModelSpeedKind
  var measuredAt: String?
  var profile: String?
  var source: String
  var value: Double?

  var label: String? {
    switch kind {
    case .realtime:
      "Realtime"
    case .effectiveTPS:
      value.map {
        (approximate ? "~" : "")
          + $0.formatted(.number.precision(.fractionLength(0...1)))
          + " effective tok/s"
      }
    case .rtfx:
      value.map {
        $0.formatted(.number.precision(.fractionLength(0...1))) + "× realtime"
      }
    }
  }
}

struct CatalogModelIntelligence: Decodable, Equatable, Sendable {
  var displayScore: Double
  var index: Double
  var measuredAt: String
  var profile: String
  var source: String
  var sourceVersion: String

  var label: String {
    displayScore.formatted(.number.precision(.fractionLength(1))) + "/10 intelligence"
  }
}

struct CatalogTranscriptionRoute: Decodable, Equatable, Sendable {
  var model: String
  var provider: String
  var supportedLanguages: [String]
  var supportsAutomaticLanguage: Bool
  var supportsDiarization: Bool
  var upstreamModel: String
}

extension CatalogTranscriptionRoute {
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

struct CatalogTranscriptionRoutes: Decodable, Equatable, Sendable {
  var batch: CatalogTranscriptionRoute?
  var realtime: CatalogTranscriptionRoute?
}

struct CatalogModel: Decodable, Equatable, Identifiable, Sendable {
  var accuracy: CatalogModelAccuracy?
  var id: String
  var intelligence: CatalogModelIntelligence?
  var kind: CatalogModelKind
  var provider: String
  var routes: CatalogTranscriptionRoutes?
  var speed: CatalogModelSpeed?
  var upstreamModel: String

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

  var batchRoute: CatalogTranscriptionRoute? {
    routes?.batch
  }

  var realtimeRoute: CatalogTranscriptionRoute? {
    routes?.realtime
  }

  var presentationLabel: String? {
    let labels = [speed?.label, accuracy?.label, intelligence?.label].compactMap { $0 }
    return labels.isEmpty ? nil : labels.joined(separator: " · ")
  }
}
