import Observation

@MainActor
@Observable
final class CloudModelCatalogStore {
  static let shared = CloudModelCatalogStore()

  private let client: CloudModelCatalogClient
  private var hasLoaded = false

  private(set) var isLoading = false
  private(set) var lastError: String?
  private(set) var models: [CloudModelSpec] = []

  var hasLoadedSuccessfully: Bool { hasLoaded }

  init(client: CloudModelCatalogClient = .production) {
    self.client = client
  }

  var batchTranscriptionModels: [CloudModelSpec] {
    models.filter(\.isBatchTranscription).sorted { $0.menuLabel < $1.menuLabel }
  }

  var realtimeTranscriptionModels: [CloudModelSpec] {
    models.filter(\.isRealtimeTranscription).sorted { $0.menuLabel < $1.menuLabel }
  }

  var audioTranscriptionModels: [CloudModelSpec] {
    models
      .filter { $0.kind == .transcription && ($0.batchRoute != nil || $0.realtimeRoute != nil) }
      .sorted { $0.menuLabel < $1.menuLabel }
  }

  var languageModels: [CloudModelSpec] {
    models.filter(\.isLanguageModel).sorted { $0.menuLabel < $1.menuLabel }
  }

  func model(id: String) -> CloudModelSpec? {
    models.first { $0.id == id }
  }

  func refreshIfNeeded() async {
    guard !hasLoaded else { return }
    await refresh()
  }

  func refresh() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }

    do {
      models = try await client.models()
      hasLoaded = true
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
  }
}
