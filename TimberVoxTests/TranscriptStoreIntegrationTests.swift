import XCTest

@testable import TimberVox

/// Uses a real temporary SQLite database through the production GRDB store.
final class TranscriptStoreIntegrationTests: XCTestCase {
  func testRealDatabaseSaveSearchAndDeleteRoundTrip() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("TimberVoxIntegration-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = TranscriptStore(directory: directory)

    let saved = try store.save(
      text: "A searchable TimberVox transcript",
      duration: 1.25,
      model: "integration-model",
      audioPath: nil
    )

    XCTAssertEqual(try store.recent().map(\.text), [saved.text])
    XCTAssertEqual(try store.search("searchable").map(\.text), [saved.text])

    let savedID = try XCTUnwrap(saved.id)
    try store.delete(id: savedID)
    XCTAssertTrue(try store.recent().isEmpty)
  }
}
