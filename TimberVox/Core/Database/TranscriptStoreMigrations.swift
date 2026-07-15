import GRDB

extension TranscriptStore {
  static func migrate(_ database: some DatabaseWriter) throws {
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
    migrator.registerMigration("v4-history-presentation") { db in
      try db.alter(table: "transcripts") { table in
        table.add(column: "segmentsJSON", .text)
        table.add(column: "sourceApplicationName", .text)
        table.add(column: "sourceApplicationBundleIdentifier", .text)
      }
    }
    migrator.registerMigration("v5-import-provenance") { db in
      try db.alter(table: "transcripts") { table in
        table.add(column: "importSource", .text)
        table.add(column: "importExternalID", .text)
      }
      try db.create(
        index: "transcripts_on_import_source_and_external_id",
        on: "transcripts",
        columns: ["importSource", "importExternalID"],
        options: .unique
      )
    }
    migrator.registerMigration("v6-transcription-artifact") { db in
      try db.alter(table: "transcripts") { table in
        table.add(column: "artifactJSON", .text)
      }
    }
    migrator.registerMigration("v7-text-transform-artifact") { db in
      try db.alter(table: "transcripts") { table in
        table.add(column: "transformArtifactJSON", .text)
      }
    }
    registerCurrentPayloadMigrations(on: &migrator)
    try migrator.migrate(database)
  }

  private static func registerCurrentPayloadMigrations(
    on migrator: inout DatabaseMigrator
  ) {
    registerCanonicalPayloadMigration(on: &migrator)
    registerDictationOutcomeMigration(on: &migrator)
    registerContextSnapshotMigration(on: &migrator)
    registerLegacyProjectionCompatibilityMigration(on: &migrator)
    registerWordCountMigration(on: &migrator)
  }

  private static func registerWordCountMigration(
    on migrator: inout DatabaseMigrator
  ) {
    migrator.registerMigration("v12-word-count") { db in
      try db.alter(table: "transcripts") { table in
        table.add(column: "wordCount", .integer).notNull().defaults(to: 0)
      }
      let rows = try Row.fetchAll(db, sql: "SELECT id, text FROM transcripts")
      let update = try db.makeStatement(sql: "UPDATE transcripts SET wordCount = ? WHERE id = ?")
      for row in rows {
        let id: Int64 = row["id"]
        let text: String = row["text"]
        try update.execute(arguments: [TranscriptStore.wordCount(of: text), id])
      }
    }
  }

  private static func registerLegacyProjectionCompatibilityMigration(
    on migrator: inout DatabaseMigrator
  ) {
    migrator.registerMigration("v11-legacy-projection-columns") { db in
      let columns = Set(try db.columns(in: "transcripts").map(\.name))
      let needsProviderLatency = !columns.contains("legacyProviderLatencyMs")
      let needsSegments = !columns.contains("legacySegmentsJSON")
      guard needsProviderLatency || needsSegments else { return }

      try db.alter(table: "transcripts") { table in
        if needsProviderLatency {
          table.add(column: "legacyProviderLatencyMs", .double)
        }
        if needsSegments {
          table.add(column: "legacySegmentsJSON", .text)
        }
      }
    }
  }

  private static func registerContextSnapshotMigration(
    on migrator: inout DatabaseMigrator
  ) {
    migrator.registerMigration("v10-context-snapshot") { db in
      try db.alter(table: "transcripts") { table in
        table.add(column: "contextSnapshotJSON", .text)
      }
    }
  }

  private static func registerDictationOutcomeMigration(
    on migrator: inout DatabaseMigrator
  ) {
    migrator.registerMigration("v9-dictation-outcomes") { db in
      try db.alter(table: "transcripts") { table in
        table.add(column: "status", .text).notNull().defaults(
          to: TranscriptRecordStatus.succeeded.rawValue
        )
        table.add(column: "errorCode", .text)
        table.add(column: "errorMessage", .text)
      }
      try db.create(
        index: "transcripts_on_status_and_created_at",
        on: "transcripts",
        columns: ["status", "createdAt"]
      )
    }
  }

  private static func registerCanonicalPayloadMigration(
    on migrator: inout DatabaseMigrator
  ) {
    migrator.registerMigration("v8-canonical-dictation-payloads") { db in
      try db.alter(table: "transcripts") { table in
        table.rename(column: "artifactJSON", to: "transcriptionArtifactJSON")
      }
      try db.alter(table: "transcripts") { table in
        table.rename(column: "transformArtifactJSON", to: "transformationJSON")
      }
      try db.alter(table: "transcripts") { table in
        table.rename(column: "providerLatencyMs", to: "legacyProviderLatencyMs")
      }
      try db.alter(table: "transcripts") { table in
        table.rename(column: "segmentsJSON", to: "legacySegmentsJSON")
      }
      try db.alter(table: "transcripts") { table in
        table.add(column: "wallLatencyMs", .double)
      }
    }
  }
}
