import Foundation

struct CloudModelCatalogClient: Sendable {
  static let production = CloudModelCatalogClient(baseURL: CloudHTTPClient.productionBaseURL)

  var api: CloudHTTPClient

  init(baseURL: URL, session: URLSession = .shared) {
    api = CloudHTTPClient(baseURL: baseURL, session: session)
  }

  func models() async throws -> [CloudModelSpec] {
    let response: CloudModelsResponse = try await api.get(
      path: "v1/models",
      authorized: false
    )
    return response.models
  }
}

struct CloudModelsResponse: Decodable {
  var models: [CloudModelSpec]
}
