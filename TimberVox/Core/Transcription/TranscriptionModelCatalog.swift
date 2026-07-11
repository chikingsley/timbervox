import Foundation

enum TranscriptionModelRuntime: String, Equatable, Sendable {
  case cloud
  case local

  var label: String {
    switch self {
    case .cloud: "Cloud"
    case .local: "Local"
    }
  }
}

enum LocalTranscriptionRouteID: String, Equatable, Sendable {
  case nemotronEnglish1120 = "nemotron-1120ms"
  case nemotronEnglish560 = "nemotron-560ms"
  case nemotronMultilingual1120 = "nemotron-multilingual-1120ms"
  case parakeetTdtCtc110M = "parakeet-tdt-ctc-110m-coreml"
  case parakeetTdtV3 = "parakeet-tdt-0.6b-v3-coreml"
}

enum TranscriptionRouteExecutor: Equatable, Sendable {
  case cloud
  case local(LocalTranscriptionRouteID)
}

struct TranscriptionRouteSpec: Equatable, Sendable {
  var model: String
  var provider: String
  var supportedLanguages: [String]
  var supportsAutomaticLanguage: Bool
  var supportsDiarization: Bool
  var upstreamModel: String
  var executor: TranscriptionRouteExecutor
}

struct TranscriptionModelRoutes: Equatable, Sendable {
  var batch: TranscriptionRouteSpec?
  var realtime: TranscriptionRouteSpec?
}

enum ModelRatingBasis: String, Equatable, Sendable {
  case curatedEstimate
  case productionMeasurement
  case publishedEvidence
  case timberVoxBenchmark
}

struct ModelRating: Equatable, Sendable {
  var score: Int
  var basis: ModelRatingBasis
  var explanation: String

  init(score: Int, basis: ModelRatingBasis, explanation: String) {
    self.score = min(max(score, 1), 5)
    self.basis = basis
    self.explanation = explanation
  }
}

struct TranscriptionModelPresentation: Equatable, Sendable {
  var summary: String
  var quality: ModelRating?
  var response: ModelRating?
  var approximateDownloadBytes: Int64?
}

struct TranscriptionModelSpec: Equatable, Identifiable, Sendable {
  var id: String
  var displayName: String
  var technicalName: String?
  var provider: String
  var runtime: TranscriptionModelRuntime
  var routes: TranscriptionModelRoutes
  var presentation: TranscriptionModelPresentation

  var supportsBatch: Bool { batchRoute != nil }
  var supportsRealtime: Bool { realtimeRoute != nil }
  var batchRoute: TranscriptionRouteSpec? { routes.batch }
  var realtimeRoute: TranscriptionRouteSpec? { routes.realtime }

  var menuLabel: String {
    "\(displayName) (\(runtime.label))"
  }
}

enum LocalTranscriptionModelCatalog {
  static let models = [hummingbird, nightingale, songbird]

  private static let english = ["en"]
  private static let parakeetV3Languages = [
    "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "hr", "hu", "it",
    "lt", "lv", "mt", "nl", "pl", "pt", "ro", "ru", "sk", "sl", "sv", "uk",
  ]
  private static let nemotronMultilingualLanguages = ["de", "en", "es", "fr", "it", "ja", "pt", "zh"]

  private static let hummingbird = TranscriptionModelSpec(
    id: "local-hummingbird",
    displayName: "Hummingbird",
    technicalName: "Parakeet 110M + Nemotron 560",
    provider: "FluidAudio",
    runtime: .local,
    routes: TranscriptionModelRoutes(
      batch: route(
        .parakeetTdtCtc110M,
        languages: english,
        supportsAutomaticLanguage: false
      ),
      realtime: route(
        .nemotronEnglish560,
        languages: english,
        supportsAutomaticLanguage: false
      )
    ),
    presentation: TranscriptionModelPresentation(
      summary: "Fast, lightweight English dictation.",
      quality: ModelRating(
        score: 4,
        basis: .publishedEvidence,
        explanation: "Strong English accuracy from the compact 110M final-transcript model."
      ),
      response: ModelRating(
        score: 5,
        basis: .publishedEvidence,
        explanation: "Uses the lowest-latency 560 ms English streaming route."
      ),
      approximateDownloadBytes: 1_750_000_000
    )
  )

  private static let nightingale = TranscriptionModelSpec(
    id: "local-nightingale",
    displayName: "Nightingale",
    technicalName: "Parakeet v3 + Nemotron 1120",
    provider: "FluidAudio",
    runtime: .local,
    routes: TranscriptionModelRoutes(
      batch: route(
        .parakeetTdtV3,
        languages: parakeetV3Languages,
        supportsAutomaticLanguage: true
      ),
      realtime: route(
        .nemotronEnglish1120,
        languages: english,
        supportsAutomaticLanguage: false
      )
    ),
    presentation: TranscriptionModelPresentation(
      summary: "Highest-quality local English dictation.",
      quality: ModelRating(
        score: 5,
        basis: .curatedEstimate,
        explanation: "Uses the larger Parakeet v3 model for the final transcript."
      ),
      response: ModelRating(
        score: 4,
        basis: .publishedEvidence,
        explanation: "The 1120 ms route favors quality while remaining responsive."
      ),
      approximateDownloadBytes: 2_050_000_000
    )
  )

  private static let songbird = TranscriptionModelSpec(
    id: "local-songbird",
    displayName: "Songbird",
    technicalName: "Parakeet v3 + Nemotron Multilingual 1120",
    provider: "FluidAudio",
    runtime: .local,
    routes: TranscriptionModelRoutes(
      batch: route(
        .parakeetTdtV3,
        languages: parakeetV3Languages,
        supportsAutomaticLanguage: true
      ),
      realtime: route(
        .nemotronMultilingual1120,
        languages: nemotronMultilingualLanguages,
        supportsAutomaticLanguage: false
      )
    ),
    presentation: TranscriptionModelPresentation(
      summary: "Private multilingual dictation in eight realtime languages.",
      quality: ModelRating(
        score: 4,
        basis: .curatedEstimate,
        explanation: "Quality varies by language; the final transcript uses Parakeet v3."
      ),
      response: ModelRating(
        score: 3,
        basis: .publishedEvidence,
        explanation: "The larger multilingual vocabulary trades some response speed for coverage."
      ),
      approximateDownloadBytes: 2_050_000_000
    )
  )

  private static func route(
    _ id: LocalTranscriptionRouteID,
    languages: [String],
    supportsAutomaticLanguage: Bool
  ) -> TranscriptionRouteSpec {
    TranscriptionRouteSpec(
      model: id.rawValue,
      provider: "FluidAudio",
      supportedLanguages: languages,
      supportsAutomaticLanguage: supportsAutomaticLanguage,
      supportsDiarization: false,
      upstreamModel: id.rawValue,
      executor: .local(id)
    )
  }
}

extension CloudModelSpec {
  var transcriptionModelSpec: TranscriptionModelSpec? {
    guard kind == .transcription else { return nil }
    return TranscriptionModelSpec(
      id: id,
      displayName: displayName,
      technicalName: upstreamModel,
      provider: provider.capitalized,
      runtime: .cloud,
      routes: TranscriptionModelRoutes(
        batch: batchRoute.map(TranscriptionRouteSpec.init),
        realtime: realtimeRoute.map(TranscriptionRouteSpec.init)
      ),
      presentation: TranscriptionModelPresentation(
        summary: "Cloud transcription from \(provider.capitalized).",
        quality: nil,
        response: nil,
        approximateDownloadBytes: nil
      )
    )
  }
}

private extension TranscriptionRouteSpec {
  init(_ cloudRoute: CloudModelRouteSpec) {
    self.init(
      model: cloudRoute.model,
      provider: cloudRoute.provider,
      supportedLanguages: cloudRoute.supportedLanguages,
      supportsAutomaticLanguage: cloudRoute.supportsAutomaticLanguage,
      supportsDiarization: cloudRoute.supportsDiarization,
      upstreamModel: cloudRoute.upstreamModel,
      executor: .cloud
    )
  }
}
