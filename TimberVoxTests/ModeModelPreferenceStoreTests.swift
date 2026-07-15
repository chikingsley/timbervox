import Foundation
import XCTest

@testable import TimberVox

@MainActor
final class ModeModelPreferenceStoreTests: XCTestCase {
  func testFavoriteTogglePersistsAcrossStoreInstances() throws {
    let suiteName = "ModeModelPreferenceStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = ModeModelPreferenceStore(defaults: defaults)
    XCTAssertFalse(store.isFavorite("local-nightingale"))

    store.toggleFavorite("local-nightingale")
    XCTAssertTrue(store.isFavorite("local-nightingale"))
    XCTAssertTrue(
      ModeModelPreferenceStore(defaults: defaults).isFavorite("local-nightingale")
    )

    store.toggleFavorite("local-nightingale")
    XCTAssertFalse(store.isFavorite("local-nightingale"))
  }
}
