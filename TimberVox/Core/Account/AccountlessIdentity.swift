import Foundation

struct AccountlessIdentity: Sendable {
  static let current = load()

  let appUserID: String
  let installationID: String

  private static func load() -> AccountlessIdentity {
    let appUserID = loadOrCreate(
      key: "accountlessRevenueCatAppUserID",
      prefix: "rc_user"
    )
    let installationID = loadOrCreate(
      key: "accountlessInstallationID",
      prefix: "installation"
    )
    return AccountlessIdentity(
      appUserID: appUserID,
      installationID: installationID
    )
  }

  private static func loadOrCreate(
    key: String,
    prefix: String
  ) -> String {
    let defaults = UserDefaults.standard
    if let existing = defaults.string(forKey: key) {
      return existing
    }
    let value = "\(prefix)_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
    defaults.set(value, forKey: key)
    return value
  }
}
