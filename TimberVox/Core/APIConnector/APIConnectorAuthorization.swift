import Foundation
import PeacockeryVoiceClient

actor APIConnectorAuthorization {
  #if DEBUG
    static let shared = APIConnectorAuthorization(apiKey: configuredAPIKey())
  #else
    static let shared = APIConnectorAuthorization(
      credentialManager: PeacockeryVoiceAppStoreCredentialManager(
        appBundleID: "studio.peacockery.timbervox",
        environment: .production,
        signer: PeacockeryVoiceSecureEnclaveSigner(
          applicationTag: "studio.peacockery.timbervox.voice-dpop"
        )
      )
    )
  #endif

  private enum Backend: Sendable {
    case bearer(String?)
    case dpop(PeacockeryVoiceAppStoreCredentialManager)
  }

  private let backend: Backend

  init(apiKey: String?) {
    backend = .bearer(apiKey)
  }

  init(credentialManager: PeacockeryVoiceAppStoreCredentialManager) {
    backend = .dpop(credentialManager)
  }

  func authorize(
    _ request: URLRequest,
    withFreshNonce: Bool = false
  ) async throws -> URLRequest {
    switch backend {
    case .bearer(let apiKey):
      guard let apiKey, !apiKey.isEmpty else {
        throw APIConnectorError.configuration(
          "Set PEACOCKERY_VOICE_API_KEY explicitly for this Debug build."
        )
      }
      var authorized = request
      authorized.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
      return authorized
    case .dpop(let credentialManager):
      return try await credentialManager.authorize(
        request,
        withFreshNonce: withFreshNonce
      )
    }
  }

  func acceptNonce(from response: HTTPURLResponse) async -> Bool {
    switch backend {
    case .bearer:
      false
    case .dpop(let credentialManager):
      await credentialManager.acceptNonce(from: response)
    }
  }

  func voiceClient(
    environment: PeacockeryVoiceEnvironment
  ) throws -> PeacockeryVoiceClient.Client {
    switch backend {
    case .bearer(let apiKey):
      guard let apiKey, !apiKey.isEmpty else {
        throw APIConnectorError.configuration(
          "Set PEACOCKERY_VOICE_API_KEY explicitly for this Debug build."
        )
      }
      return PeacockeryVoiceClients.make(environment: environment, apiKey: apiKey)
    case .dpop(let credentialManager):
      return PeacockeryVoiceClients.make(
        environment: environment,
        credentialManager: credentialManager
      )
    }
  }

  private static func configuredAPIKey() -> String? {
    ProcessInfo.processInfo.environment["PEACOCKERY_VOICE_API_KEY"]?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nilIfEmpty
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
