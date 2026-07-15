import Observation

@MainActor
@Observable
final class TranscriptionModelCatalogStore {
  static let shared = TranscriptionModelCatalogStore()

  private let catalog: ModelCatalogStore

  init(catalog: ModelCatalogStore = .shared) {
    self.catalog = catalog
  }

  var isLoading: Bool { catalog.isLoading }
  var lastError: String? { catalog.lastError }
  var languageModels: [CatalogModel] { catalog.languageModels }

  var models: [TranscriptionModelSpec] {
    let cloudModels = catalog.models.compactMap(\.transcriptionModelSpec)
    return (LocalTranscriptionModelCatalog.models + cloudModels)
      .sorted { $0.menuLabel < $1.menuLabel }
  }

  var batchModels: [TranscriptionModelSpec] {
    models.filter(\.supportsBatch)
  }

  func model(id: String) -> TranscriptionModelSpec? {
    models.first { $0.id == id }
  }

  func displayName(forRouteModel routeModel: String) -> String {
    if let localRoute = LocalTranscriptionRouteID(rawValue: routeModel) {
      return localRoute.displayName
    }
    return models.first {
      $0.batchRoute?.model == routeModel || $0.realtimeRoute?.model == routeModel
    }?.displayName ?? routeModel
  }

  func normalized(_ mode: DictationMode) -> DictationMode {
    let isKnownLocalSelection = LocalTranscriptionModelCatalog.models.contains { $0.id == mode.audioModelID }
    return ModeCatalogResolver.normalized(
      mode,
      catalog: models,
      fallbackIfModelMissing: catalog.hasLoadedSuccessfully || isKnownLocalSelection
    )
  }

  func refreshIfNeeded() async {
    await catalog.refreshIfNeeded()
  }

  func refresh() async {
    await catalog.refresh()
  }
}
