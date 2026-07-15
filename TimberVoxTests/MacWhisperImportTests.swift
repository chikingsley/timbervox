import GRDB
import XCTest

@testable import TimberVox

@MainActor
final class MacWhisperImportTests: XCTestCase {
  func testImportPreservesMetadataAndIsIdempotent() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("MacWhisperImport-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceDirectory = root.appendingPathComponent("Source", isDirectory: true)
    let mediaDirectory = sourceDirectory.appendingPathComponent("ExternalMedia", isDirectory: true)
    let destinationDirectory = root.appendingPathComponent("Imported", isDirectory: true)
    let targetDirectory = root.appendingPathComponent("TimberVox", isDirectory: true)
    try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)

    let sourceDatabaseURL = sourceDirectory.appendingPathComponent("main.sqlite")
    try makeSourceDatabase(at: sourceDatabaseURL)

    let store = TranscriptStore(directory: targetDirectory)
    let importer = MacWhisperImporter(
      sourceDatabaseURL: sourceDatabaseURL,
      sourceMediaDirectory: mediaDirectory,
      destinationMediaDirectory: destinationDirectory,
      transcriptStore: store
    )

    let first = try importer.run()
    let second = try importer.run()
    let record = try XCTUnwrap(store.recent().first)

    XCTAssertEqual(first.importedRecords, 1)
    XCTAssertEqual(second.skippedRecords, 1)
    XCTAssertEqual(record.text, "Imported voice to text")
    XCTAssertEqual(record.model, MacWhisperImporter.modelID)
    XCTAssertEqual(record.modeID, MacWhisperImporter.modeID)
    XCTAssertEqual(record.modeName, "Voice to text")
    XCTAssertEqual(record.sourceApplicationName, "Notes")
    XCTAssertEqual(record.sourceApplicationBundleIdentifier, "com.apple.Notes")
    XCTAssertEqual(record.importSource, MacWhisperImporter.importSource)
    XCTAssertEqual(record.importExternalID, String(repeating: "2a", count: 16))
  }

  private func makeSourceDatabase(at url: URL) throws {
    let sourceQueue = try DatabaseQueue(path: url.path)
    try sourceQueue.write { database in
      try database.execute(
        sql: """
          CREATE TABLE dictation (
            id BLOB NOT NULL,
            dateCreated TEXT NOT NULL,
            transcribedText TEXT NOT NULL,
            transcriptionDidSucceed INTEGER NOT NULL,
            targetAppLocalizedName TEXT,
            targetAppBundleID TEXT,
            mediaFileID BLOB,
            dateDeleted TEXT
          );
          CREATE TABLE mediafile (id BLOB NOT NULL, filename TEXT);
          """
      )
      try database.execute(
        sql: """
          INSERT INTO dictation (
            id, dateCreated, transcribedText, transcriptionDidSucceed,
            targetAppLocalizedName, targetAppBundleID
          ) VALUES (?, ?, ?, 1, ?, ?)
          """,
        arguments: [
          Data(repeating: 0x2A, count: 16),
          "2026-07-14 14:46:13.477",
          "Imported voice to text",
          "Notes",
          "com.apple.Notes",
        ]
      )
    }

  }

  func testImportsLiveLibraryWhenExplicitlyEnabled() throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: "/tmp/timbervox-import-macwhisper"),
      "Run `just import-macwhisper` to import the live MacWhisper library."
    )

    ModeStore.shared.ensureMode(MacWhisperImporter.voiceToTextMode)
    let result = try MacWhisperImporter.live().run()

    print(
      "MacWhisper import: \(result.importedRecords) imported, "
        + "\(result.skippedRecords) skipped, "
        + "\(result.copiedAudioFiles) audio files copied, "
        + "\(result.missingAudioFiles) missing audio files."
    )
    XCTAssertGreaterThan(result.importedRecords + result.skippedRecords, 0)
  }
}
