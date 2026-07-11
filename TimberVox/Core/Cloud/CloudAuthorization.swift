import Foundation

actor CloudAuthorization {
  static let shared = CloudAuthorization(apiKey: configuredAPIKey())

  private let apiKey: String?

  init(apiKey: String?) {
    self.apiKey = apiKey
  }

  func credential() throws -> String {
    guard let apiKey, !apiKey.isEmpty else {
      throw TimberVoxCloudError.configuration(
        "This build does not have a TimberVox Cloud API key."
      )
    }
    return apiKey
  }

  private static func configuredAPIKey() -> String? {
    let environmentValue = ProcessInfo.processInfo.environment[
      "TIMBERVOX_API_KEY"
    ]
    let bundledValue =
      Bundle.main.object(
        forInfoDictionaryKey: "TimberVoxAPIKey"
      ) as? String
    let developmentValue = UserDefaults.standard.string(
      forKey: "TimberVoxAPIKey"
    )
    return [environmentValue, bundledValue, developmentValue]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty && !$0.contains("$(TIMBERVOX_API_KEY)") }
  }
}
