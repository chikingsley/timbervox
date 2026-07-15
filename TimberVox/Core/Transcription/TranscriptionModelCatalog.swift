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

  var displayName: String {
    switch self {
    case .nemotronEnglish1120: "Nemotron 1120"
    case .nemotronEnglish560: "Nemotron 560"
    case .nemotronMultilingual1120: "Nemotron Multilingual 1120"
    case .parakeetTdtCtc110M: "Parakeet 110M"
    case .parakeetTdtV3: "Parakeet v3"
    }
  }
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
  var accuracy: CatalogModelAccuracy?
  var summary: String
  var quality: ModelRating?
  var response: ModelRating?
  var speed: CatalogModelSpeed?
  var approximateDownloadBytes: Int64?

  var metricLabel: String? {
    let labels = [speed?.label, accuracy?.label].compactMap { $0 }
    return labels.isEmpty ? nil : labels.joined(separator: " · ")
  }
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
    provider: "NVIDIA",
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
      accuracy: CatalogModelAccuracy(
        benchmark: "FluidAudio LibriSpeech test-clean",
        metric: "wer",
        source: "fluid-audio",
        value: 3.01
      ),
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
      speed: CatalogModelSpeed(
        approximate: false,
        kind: .realtime,
        measuredAt: nil,
        profile: nil,
        source: "route-capability",
        value: nil
      ),
      approximateDownloadBytes:
        FluidAudioModelPackageCatalog.package(id: "local-hummingbird")?.estimatedDownloadBytes
    )
  )

  private static let nightingale = TranscriptionModelSpec(
    id: "local-nightingale",
    displayName: "Nightingale",
    technicalName: "Parakeet v3 + Nemotron 1120",
    provider: "NVIDIA",
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
      accuracy: CatalogModelAccuracy(
        benchmark: "FluidAudio LibriSpeech test-clean",
        metric: "wer",
        source: "fluid-audio",
        value: 2.6
      ),
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
      speed: CatalogModelSpeed(
        approximate: false,
        kind: .realtime,
        measuredAt: nil,
        profile: nil,
        source: "route-capability",
        value: nil
      ),
      approximateDownloadBytes:
        FluidAudioModelPackageCatalog.package(id: "local-nightingale")?.estimatedDownloadBytes
    )
  )

  private static let songbird = TranscriptionModelSpec(
    id: "local-songbird",
    displayName: "Songbird",
    technicalName: "Parakeet v3 + Nemotron Multilingual 1120",
    provider: "NVIDIA",
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
      accuracy: CatalogModelAccuracy(
        benchmark: "FluidAudio LibriSpeech test-clean",
        metric: "wer",
        source: "fluid-audio",
        value: 2.6
      ),
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
      speed: CatalogModelSpeed(
        approximate: false,
        kind: .realtime,
        measuredAt: nil,
        profile: nil,
        source: "route-capability",
        value: nil
      ),
      approximateDownloadBytes:
        FluidAudioModelPackageCatalog.package(id: "local-songbird")?.estimatedDownloadBytes
    )
  )

  private static func route(
    _ id: LocalTranscriptionRouteID,
    languages: [String],
    supportsAutomaticLanguage: Bool
  ) -> TranscriptionRouteSpec {
    TranscriptionRouteSpec(
      model: id.rawValue,
      provider: "nvidia",
      supportedLanguages: languages,
      supportsAutomaticLanguage: supportsAutomaticLanguage,
      supportsDiarization: false,
      upstreamModel: id.rawValue,
      executor: .local(id)
    )
  }
}

extension CatalogModel {
  var menuLabel: String {
    "\(displayName) (\(provider.capitalized))"
  }

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
        accuracy: accuracy,
        summary: "Cloud transcription from \(provider.capitalized).",
        quality: nil,
        response: nil,
        speed: speed,
        approximateDownloadBytes: nil
      )
    )
  }
}

private extension TranscriptionRouteSpec {
  init(_ cloudRoute: CatalogTranscriptionRoute) {
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
