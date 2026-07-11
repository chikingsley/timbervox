import Foundation
import GRDB

struct TranscriptRecord: Identifiable, Codable, Sendable, FetchableRecord,
  MutablePersistableRecord
{
  static let databaseTableName = "transcripts"

  var id: Int64?
  var text: String
  var rawText: String?
  var createdAt: Date
  var durationSeconds: Double
  var model: String
  var modeID: String?
  var modeName: String?
  var audioPath: String?
  var provider: String?
  var providerLatencyMs: Double?
  var language: String?
  var transformPreset: String?
  var transformModel: String?

  mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}

/// Every dictation, persisted. SQLite via GRDB at
/// ~/Library/Application Support/TimberVox/timbervox.sqlite — schema grows by
/// migration when modes/source-app land (old-app kept richer columns).
final class TranscriptStore: Sendable {
  static let shared = TranscriptStore()

  private let dbQueue: DatabaseQueue?
  private let initializationErrorDescription: String?

  init(directory: URL? = nil) {
    do {
      let directory = try directory ?? Self.defaultDirectory()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let queue = try DatabaseQueue(path: directory.appendingPathComponent("timbervox.sqlite").path)
      try Self.migrate(queue)
      dbQueue = queue
      initializationErrorDescription = nil
    } catch {
      dbQueue = nil
      initializationErrorDescription = error.localizedDescription
    }
  }

  private static func migrate(_ dbQueue: DatabaseQueue) throws {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1") { db in
      try db.create(table: "transcripts") { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("text", .text).notNull()
        table.column("createdAt", .datetime).notNull().indexed()
        table.column("durationSeconds", .double).notNull()
        table.column("model", .text).notNull()
        table.column("audioPath", .text)
      }
    }
    migrator.registerMigration("v2-metadata") { db in
      try db.alter(table: "transcripts") { table in
        table.add(column: "provider", .text)
        table.add(column: "providerLatencyMs", .double)
        table.add(column: "language", .text)
      }
    }
    migrator.registerMigration("v3-modes-and-raw-text") { db in
      try db.alter(table: "transcripts") { table in
        table.add(column: "rawText", .text)
        table.add(column: "modeID", .text)
        table.add(column: "modeName", .text)
        table.add(column: "transformPreset", .text)
        table.add(column: "transformModel", .text)
      }
    }
    try migrator.migrate(dbQueue)
  }

  @discardableResult
  func save(
    text: String,
    rawText: String? = nil,
    duration: TimeInterval,
    model: String,
    modeID: String? = nil,
    modeName: String? = nil,
    audioPath: String?,
    provider: String? = nil,
    providerLatencyMs: Double? = nil,
    language: String? = nil,
    transformPreset: String? = nil,
    transformModel: String? = nil
  ) throws -> TranscriptRecord {
    let dbQueue = try databaseQueue()
    var record = TranscriptRecord(
      id: nil,
      text: text,
      rawText: rawText,
      createdAt: .now,
      durationSeconds: duration,
      model: model,
      modeID: modeID,
      modeName: modeName,
      audioPath: audioPath,
      provider: provider,
      providerLatencyMs: providerLatencyMs,
      language: language,
      transformPreset: transformPreset,
      transformModel: transformModel
    )
    try dbQueue.write { db in
      try record.insert(db)
    }
    return record
  }

  func recent(limit: Int = 200) throws -> [TranscriptRecord] {
    let dbQueue = try databaseQueue()
    return try dbQueue.read { db in
      try TranscriptRecord
        .order(Column("createdAt").desc)
        .limit(limit)
        .fetchAll(db)
    }
  }

  func search(_ query: String, limit: Int = 200) throws -> [TranscriptRecord] {
    let dbQueue = try databaseQueue()
    return try dbQueue.read { db in
      try TranscriptRecord
        .filter(Column("text").like("%\(query)%"))
        .order(Column("createdAt").desc)
        .limit(limit)
        .fetchAll(db)
    }
  }

  func delete(id: Int64) throws {
    let dbQueue = try databaseQueue()
    _ = try dbQueue.write { db in
      try TranscriptRecord.deleteOne(db, key: id)
    }
  }

  private func databaseQueue() throws -> DatabaseQueue {
    guard let dbQueue else {
      throw TranscriptStoreError.initializationFailed(
        initializationErrorDescription ?? "Unknown database initialization error."
      )
    }
    return dbQueue
  }

  private static func defaultDirectory() throws -> URL {
    guard
      let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else {
      throw TranscriptStoreError.applicationSupportDirectoryUnavailable
    }
    return applicationSupport.appendingPathComponent("TimberVox")
  }
}

enum TranscriptStoreError: LocalizedError {
  case applicationSupportDirectoryUnavailable
  case initializationFailed(String)

  var errorDescription: String? {
    switch self {
    case .applicationSupportDirectoryUnavailable:
      "Application Support is unavailable."
    case .initializationFailed(let message):
      "Transcript database could not be opened: \(message)"
    }
  }
}
