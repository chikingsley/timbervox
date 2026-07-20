import Foundation
import PeacockeryVoiceClient

struct ModelCatalogAPIClient: Sendable {
  static let current = ModelCatalogAPIClient(baseURL: APIConnector.defaultBaseURL)

  var sdk: PeacockeryVoiceSDK

  init(baseURL: URL) {
    sdk = PeacockeryVoiceSDK(baseURL: baseURL)
  }

  func models() async throws -> [CatalogModel] {
    let output = try await sdk.client().getV1Models()
    let payload: Components.Schemas.ModelsResponse
    switch output {
    case .ok(let response):
      payload = try response.body.json
    case .unauthorized:
      throw APIConnectorError.httpStatus(401)
    case .undocumented(let statusCode, _):
      throw APIConnectorError.httpStatus(statusCode)
    }
    let response = try sdk.localValue(payload, as: ModelCatalogResponse.self)
    if response.presentationSchemaVersion != 1 {
      throw APIConnectorError.invalidResponse
    }
    return response.models
  }
}

struct ModelCatalogResponse: Decodable {
  var models: [CatalogModel]
  var presentationSchemaVersion: Int
}
