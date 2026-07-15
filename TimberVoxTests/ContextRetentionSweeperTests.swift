import XCTest

@testable import TimberVox

/// Uses a real temporary directory with real file timestamps.
final class ContextRetentionSweeperTests: XCTestCase {
  private let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("context-retention-\(UUID().uuidString)", isDirectory: true)

  override func setUpWithError() throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
  }

  func testSweepRemovesOnlyFilesOlderThanRetention() throws {
    let oldFile = try makeFile(named: "screen-old.png", ageInDays: 40)
    let newFile = try makeFile(named: "screen-new.png", ageInDays: 5)

    let removedCount = DictationContextRetentionSweeper.sweep(
      retentionDays: 30,
      directory: directory
    )

    XCTAssertEqual(removedCount, 1)
    XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path))
  }

  func testForeverRetentionRemovesNothing() throws {
    let oldFile = try makeFile(named: "clipboard-old.png", ageInDays: 400)

    let removedCount = DictationContextRetentionSweeper.sweep(
      retentionDays: DictationContextRetentionOption.forever.rawValue,
      directory: directory
    )

    XCTAssertEqual(removedCount, 0)
    XCTAssertTrue(FileManager.default.fileExists(atPath: oldFile.path))
  }

  private func makeFile(named name: String, ageInDays: Double) throws -> URL {
    let file = directory.appendingPathComponent(name)
    try Data(name.utf8).write(to: file)
    let modifiedAt = Date().addingTimeInterval(-ageInDays * 24 * 60 * 60)
    try FileManager.default.setAttributes(
      [.modificationDate: modifiedAt],
      ofItemAtPath: file.path
    )
    return file
  }
}
