import Foundation
import PeacockeryVoiceClient

struct PeacockeryVoiceSDK: Sendable {
  static let current = PeacockeryVoiceSDK(baseURL: APIConnector.defaultBaseURL)

  let baseURL: URL

  func client() async throws -> PeacockeryVoiceClient.Client {
    try await APIConnectorAuthorization.shared.voiceClient(
      environment: try environment
    )
  }

  func sdkValue<Source: Encodable, Destination: Decodable>(
    _ source: Source,
    as destination: Destination.Type
  ) throws -> Destination {
    let data = try JSONEncoder().encode(source)
    return try JSONDecoder().decode(destination, from: data)
  }

  func localValue<Source: Encodable, Destination: Decodable>(
    _ source: Source,
    as destination: Destination.Type
  ) throws -> Destination {
    let data = try JSONEncoder().encode(source)
    return try TimberVoxJSONCoding.makeDecoder().decode(destination, from: data)
  }

  private var environment: PeacockeryVoiceEnvironment {
    get throws {
      switch baseURL {
      case APIConnector.labBaseURL:
        return .lab
      case APIConnector.productionBaseURL:
        return .production
      default:
        throw APIConnectorError.configuration(
          "The Peacockery Voice SDK supports only the lab and production origins."
        )
      }
    }
  }
}
