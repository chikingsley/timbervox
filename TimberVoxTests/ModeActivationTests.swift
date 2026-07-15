import XCTest

@testable import TimberVox

@MainActor
final class ModeActivationTests: XCTestCase {
  func testSourceApplicationSelectsMatchingModeAndFallsBackToActiveMode() throws {
    let defaults = try makeDefaults()
    let store = ModeStore(defaults: defaults)
    let appModeID = store.addMode()
    store.updateMode(id: appModeID) { mode in
      mode.activationBundleIdentifiers = ["com.apple.Notes"]
    }

    XCTAssertEqual(
      store.mode(forSourceApplicationBundleIdentifier: "com.apple.Notes").id,
      appModeID
    )
    XCTAssertEqual(
      store.mode(forSourceApplicationBundleIdentifier: "com.apple.Safari").id,
      store.activeModeID
    )
    XCTAssertEqual(store.mode(forSourceApplicationBundleIdentifier: nil).id, store.activeModeID)
  }

  func testActivationBundleIdentifiersPersistAcrossStoreReloads() throws {
    let defaults = try makeDefaults()
    let store = ModeStore(defaults: defaults)
    let appModeID = store.addMode()
    store.updateMode(id: appModeID) { mode in
      mode.activationBundleIdentifiers = ["com.apple.Notes", "com.apple.Safari"]
    }

    let reloadedStore = ModeStore(defaults: defaults)

    XCTAssertEqual(
      reloadedStore.mode(id: appModeID)?.activationBundleIdentifiers,
      ["com.apple.Notes", "com.apple.Safari"]
    )
  }

  func testLegacyModeWithoutActivationIdentifiersDecodesWithEmptySelection() throws {
    let mode = DictationMode.defaultMode()
    let encoded = try JSONEncoder().encode(mode)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    object.removeValue(forKey: "activationBundleIdentifiers")
    let legacyData = try JSONSerialization.data(withJSONObject: object)

    let decoded = try JSONDecoder().decode(DictationMode.self, from: legacyData)

    XCTAssertTrue(decoded.activationBundleIdentifiers.isEmpty)
  }

  private func makeDefaults() throws -> UserDefaults {
    let suiteName = "ModeActivationTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}
