import XCTest

@testable import TimberVox

/// Uses a real temporary directory with real file timestamps.
final class RecordingRetentionSweeperTests: XCTestCase {
  private let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("recording-retention-\(UUID().uuidString)", isDirectory: true)

  override func setUpWithError() throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
  }

  func testSweepRemovesOnlyAudioOlderThanRetention() throws {
    let oldFile = try makeFile(named: "dictation-old.wav", ageInDays: 45)
    let newFile = try makeFile(named: "dictation-new.wav", ageInDays: 2)

    let removedCount = RecordingRetentionSweeper.sweep(retentionDays: 30, directory: directory)

    XCTAssertEqual(removedCount, 1)
    XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path))
  }

  func testDefaultForeverRetentionRemovesNothing() throws {
    let oldFile = try makeFile(named: "dictation-ancient.wav", ageInDays: 500)

    let removedCount = RecordingRetentionSweeper.sweep(
      retentionDays: RecordingRetentionPreference.defaultDays,
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
