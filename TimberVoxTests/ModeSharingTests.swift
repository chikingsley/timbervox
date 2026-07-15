import Foundation
import XCTest

@testable import TimberVox

@MainActor
final class ModeSharingTests: XCTestCase {
  func testModeFileRoundTripsCurrentSchema() throws {
    let mode = DictationMode.defaultMode()
    let exportedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let original = TimberVoxModeFile(mode: mode, exportedAt: exportedAt)

    let decoded = try TimberVoxModeFile.decode(original.encoded())

    XCTAssertEqual(decoded, original)
    XCTAssertEqual(decoded.schemaVersion, 1)
  }

  func testModeFileRejectsUnsupportedSchema() throws {
    let original = TimberVoxModeFile(mode: .defaultMode())
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: original.encoded()) as? [String: Any]
    )
    object["schemaVersion"] = 2
    let data = try JSONSerialization.data(withJSONObject: object)

    XCTAssertThrowsError(try TimberVoxModeFile.decode(data)) { error in
      XCTAssertEqual(error as? TimberVoxModeFileError, .unsupportedSchema(2))
    }
  }

  func testImportedModeGetsFreshIDAndConflictSafeName() throws {
    let defaults = try makeDefaults()
    let store = ModeStore(defaults: defaults)
    var imported = DictationMode.defaultMode(defaults: defaults)
    imported.id = "shared-id"
    imported.name = store.activeMode.name

    let importedID = store.importMode(imported)

    XCTAssertNotEqual(importedID, "shared-id")
    XCTAssertEqual(store.mode(id: importedID)?.name, "Default 2")
    XCTAssertEqual(store.modes.count, 2)
  }

  func testFavoritesPersistAndRegroupSourceState() throws {
    let defaults = try makeDefaults()
    let first = ModeModelPreferenceStore(defaults: defaults)
    first.toggleFavorite("local-hummingbird")

    let reloaded = ModeModelPreferenceStore(defaults: defaults)

    XCTAssertTrue(reloaded.isFavorite("local-hummingbird"))
    reloaded.toggleFavorite("local-hummingbird")
    XCTAssertFalse(ModeModelPreferenceStore(defaults: defaults).isFavorite("local-hummingbird"))
  }

  private func makeDefaults() throws -> UserDefaults {
    let suiteName = "ModeSharingTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}
