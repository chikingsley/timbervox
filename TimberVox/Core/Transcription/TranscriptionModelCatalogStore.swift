import Observation

@MainActor
@Observable
final class TranscriptionModelCatalogStore {
  static let shared = TranscriptionModelCatalogStore()

  private let cloudCatalog: CloudModelCatalogStore

  init(cloudCatalog: CloudModelCatalogStore = .shared) {
    self.cloudCatalog = cloudCatalog
  }

  var isLoading: Bool { cloudCatalog.isLoading }
  var lastError: String? { cloudCatalog.lastError }
  var languageModels: [CloudModelSpec] { cloudCatalog.languageModels }

  var models: [TranscriptionModelSpec] {
    let cloudModels = cloudCatalog.models.compactMap(\.transcriptionModelSpec)
    return (LocalTranscriptionModelCatalog.models + cloudModels)
      .sorted { $0.menuLabel < $1.menuLabel }
  }

  var batchModels: [TranscriptionModelSpec] {
    models.filter(\.supportsBatch)
  }

  func model(id: String) -> TranscriptionModelSpec? {
    models.first { $0.id == id }
  }

  func normalized(_ mode: DictationMode) -> DictationMode {
    let isKnownLocalSelection = LocalTranscriptionModelCatalog.models.contains { $0.id == mode.audioModelID }
    return ModeCatalogResolver.normalized(
      mode,
      catalog: models,
      fallbackIfModelMissing: cloudCatalog.hasLoadedSuccessfully || isKnownLocalSelection
    )
  }

  func refreshIfNeeded() async {
    await cloudCatalog.refreshIfNeeded()
  }

  func refresh() async {
    await cloudCatalog.refresh()
  }
}
