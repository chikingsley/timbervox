import Foundation

struct CloudClients: Sendable {
  static let production = CloudClients(baseURL: CloudHTTPClient.productionBaseURL)

  let batchTranscription: CloudBatchTranscriptionClient
  let catalog: CloudModelCatalogClient
  let textTransform: CloudTextTransformClient

  private let baseURL: URL
  private let session: URLSession

  init(baseURL: URL, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
    batchTranscription = CloudBatchTranscriptionClient(baseURL: baseURL, session: session)
    catalog = CloudModelCatalogClient(baseURL: baseURL, session: session)
    textTransform = CloudTextTransformClient(baseURL: baseURL, session: session)
  }

  func makeRealtimeTranscriptionClient() -> CloudRealtimeTranscriptionClient {
    CloudRealtimeTranscriptionClient(baseURL: baseURL, session: session)
  }
}
