import Foundation
import GRDB

struct TranscriptImport: Sendable {
  var text: String
  var createdAt: Date
  var duration: TimeInterval
  var model: String
  var modeID: String
  var modeName: String
  var audioPath: String?
  var provider: String
  var sourceApplicationName: String?
  var sourceApplicationBundleIdentifier: String?
  var importSource: String
  var importExternalID: String
}

struct TranscriptFailureInput: Sendable {
  var failure: DictationFailure
  var artifact: TranscriptionArtifact?
  var duration: TimeInterval
  var model: String
  var modeID: String?
  var modeName: String?
  var audioPath: String
  var provider: String
  var language: String?
  var transformPreset: String?
  var transformModel: String?
  var transformation: TextTransformationCapture?
  var contextSnapshot: DictationContextSnapshot?
  var sourceApplicationName: String?
  var sourceApplicationBundleIdentifier: String?
}

/// Every dictation, persisted. SQLite via GRDB at
/// ~/Library/Application Support/TimberVox/timbervox.sqlite — schema grows by
/// migration when modes/source-app land (old-app kept richer columns).
final class TranscriptStore: Sendable {
  static let shared = TranscriptStore()

  private let dbPool: DatabasePool?
  private let initializationErrorDescription: String?

  init(directory: URL? = nil) {
    do {
      let directory = try directory ?? Self.defaultDirectory()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let pool = try DatabasePool(path: directory.appendingPathComponent("timbervox.sqlite").path)
      try Self.migrate(pool)
      dbPool = pool
      initializationErrorDescription = nil
    } catch {
      dbPool = nil
      initializationErrorDescription = error.localizedDescription
    }
  }

  static func wordCount(of text: String) -> Int {
    text.split(whereSeparator: \.isWhitespace).count
  }

  @discardableResult
  func save(
    text: String,
    rawText: String? = nil,
    artifact: TranscriptionArtifact,
    duration: TimeInterval,
    modeID: String? = nil,
    modeName: String? = nil,
    audioPath: String?,
    transformPreset: String? = nil,
    transformModel: String? = nil,
    transformation: TextTransformationCapture? = nil,
    contextSnapshot: DictationContextSnapshot? = nil,
    sourceApplicationName: String? = nil,
    sourceApplicationBundleIdentifier: String? = nil
  ) throws -> TranscriptRecord {
    if transformPreset != nil || transformModel != nil {
      guard transformation != nil else {
        throw TranscriptStoreError.transformationCaptureRequired
      }
    }
    let dbPool = try databasePool()
    let transcriptionArtifactJSON = try encodedArtifact(artifact)
    let transformationJSON = try transformation.map {
      let data = try TextTransformationCaptureCoders.encode($0)
      guard let json = String(data: data, encoding: .utf8) else {
        throw TranscriptStoreError.artifactEncodingFailed
      }
      return json
    }
    let contextSnapshotJSON = try contextSnapshot.map { try encodedContextSnapshot($0) }
    var record = TranscriptRecord(
      id: nil,
      text: text,
      rawText: rawText,
      createdAt: .now,
      durationSeconds: duration,
      wordCount: Self.wordCount(of: text),
      model: artifact.provenance.model,
      modeID: modeID,
      modeName: modeName,
      audioPath: audioPath,
      provider: artifact.provenance.provider,
      status: .succeeded,
      errorCode: nil,
      errorMessage: nil,
      wallLatencyMs: artifact.metrics.wallLatencyMs,
      legacyProviderLatencyMs: nil,
      language: artifact.language.detected ?? artifact.language.requested,
      transformPreset: transformPreset,
      transformModel: transformModel,
      transformationJSON: transformationJSON,
      transcriptionArtifactJSON: transcriptionArtifactJSON,
      contextSnapshotJSON: contextSnapshotJSON,
      legacySegmentsJSON: nil,
      sourceApplicationName: sourceApplicationName,
      sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier,
      importSource: nil,
      importExternalID: nil
    )
    try dbPool.write { db in
      try record.insert(db)
    }
    return record
  }

  @discardableResult
  func saveFailure(_ input: TranscriptFailureInput) throws -> TranscriptRecord {
    let dbPool = try databasePool()
    let text = input.artifact?.displayText ?? ""
    var record = TranscriptRecord(
      id: nil,
      text: text,
      rawText: input.artifact?.displayText,
      createdAt: .now,
      durationSeconds: input.duration,
      wordCount: Self.wordCount(of: text),
      model: input.model,
      modeID: input.modeID,
      modeName: input.modeName,
      audioPath: input.audioPath,
      provider: input.artifact?.provenance.provider ?? input.provider,
      status: input.failure.code == .noSpeech ? .noSpeech : .failed,
      errorCode: input.failure.code.rawValue,
      errorMessage: input.failure.message,
      wallLatencyMs: input.artifact?.metrics.wallLatencyMs,
      legacyProviderLatencyMs: nil,
      language: input.artifact?.language.detected ?? input.artifact?.language.requested ?? input.language,
      transformPreset: input.transformPreset,
      transformModel: input.transformModel,
      transformationJSON: try input.transformation.map { try encodedTransformation($0) },
      transcriptionArtifactJSON: try input.artifact.map { try encodedArtifact($0) },
      contextSnapshotJSON: try input.contextSnapshot.map { try encodedContextSnapshot($0) },
      legacySegmentsJSON: nil,
      sourceApplicationName: input.sourceApplicationName,
      sourceApplicationBundleIdentifier: input.sourceApplicationBundleIdentifier,
      importSource: nil,
      importExternalID: nil
    )
    try dbPool.write { db in
      try record.insert(db)
    }
    return record
  }

  @discardableResult
  func importRecord(_ importValue: TranscriptImport) throws -> TranscriptRecord? {
    let dbPool = try databasePool()
    return try dbPool.write { db in
      let alreadyImported =
        try TranscriptRecord
        .filter(Column("importSource") == importValue.importSource)
        .filter(Column("importExternalID") == importValue.importExternalID)
        .fetchCount(db) > 0
      guard !alreadyImported else { return nil }

      var record = TranscriptRecord(
        id: nil,
        text: importValue.text,
        rawText: nil,
        createdAt: importValue.createdAt,
        durationSeconds: importValue.duration,
        wordCount: Self.wordCount(of: importValue.text),
        model: importValue.model,
        modeID: importValue.modeID,
        modeName: importValue.modeName,
        audioPath: importValue.audioPath,
        provider: importValue.provider,
        status: .succeeded,
        errorCode: nil,
        errorMessage: nil,
        wallLatencyMs: nil,
        legacyProviderLatencyMs: nil,
        language: nil,
        transformPreset: nil,
        transformModel: nil,
        transformationJSON: nil,
        transcriptionArtifactJSON: nil,
        contextSnapshotJSON: nil,
        legacySegmentsJSON: nil,
        sourceApplicationName: importValue.sourceApplicationName,
        sourceApplicationBundleIdentifier: importValue.sourceApplicationBundleIdentifier,
        importSource: importValue.importSource,
        importExternalID: importValue.importExternalID
      )
      try record.insert(db)
      return record
    }
  }

  func recent(limit: Int = 2_000, offset: Int = 0) throws -> [TranscriptRecord] {
    let dbPool = try databasePool()
    return try dbPool.read { db in
      try TranscriptRecord
        .order(Column("createdAt").desc)
        .limit(limit, offset: offset)
        .fetchAll(db)
    }
  }

  func search(_ query: String, limit: Int = 2_000, offset: Int = 0) throws -> [TranscriptRecord] {
    let dbPool = try databasePool()
    return try dbPool.read { db in
      try TranscriptRecord
        .filter(Column("text").like("%\(query)%"))
        .order(Column("createdAt").desc)
        .limit(limit, offset: offset)
        .fetchAll(db)
    }
  }

  func count(matching query: String? = nil) throws -> Int {
    let dbPool = try databasePool()
    return try dbPool.read { db in
      guard let query, !query.isEmpty else {
        return try TranscriptRecord.fetchCount(db)
      }
      return
        try TranscriptRecord
        .filter(Column("text").like("%\(query)%"))
        .fetchCount(db)
    }
  }

  /// One full record, JSON payloads included — fetched off the main thread.
  func record(id: Int64) async throws -> TranscriptRecord? {
    let dbPool = try databasePool()
    return try await dbPool.read { db in
      try TranscriptRecord.fetchOne(db, key: id)
    }
  }

  /// Pushes a fresh Home overview whenever the transcripts table changes.
  /// The stats come from SQL aggregates; only the recent-activity rows are fetched.
  func observeHomeOverview() throws -> AsyncValueObservation<HomeDictationOverview> {
    let dbPool = try databasePool()
    return
      ValueObservation
      .tracking { db in try Self.fetchHomeOverview(db) }
      .removeDuplicates()
      .values(in: dbPool)
  }

  /// Pushes the current History page whenever the transcripts table changes.
  func observeHistoryPage(
    matching query: String,
    limit: Int
  ) throws -> AsyncValueObservation<HistoryPage> {
    let dbPool = try databasePool()
    return
      ValueObservation
      .tracking { db in try Self.fetchHistoryPage(db, query: query, limit: limit) }
      .removeDuplicates()
      .values(in: dbPool)
  }

  func delete(id: Int64) throws {
    let dbPool = try databasePool()
    let contextSnapshot = try dbPool.read { db in
      try TranscriptRecord.fetchOne(db, key: id)?.contextSnapshot
    }
    let deleted = try dbPool.write { db in
      try TranscriptRecord.deleteOne(db, key: id)
    }
    if deleted, let contextSnapshot {
      DictationContextAttachmentCleanup.removeOwnedFiles(in: contextSnapshot.attachments)
    }
  }

  func delete(id: Int64) async throws {
    let dbPool = try databasePool()
    let contextSnapshot = try await dbPool.read { db in
      try TranscriptRecord.fetchOne(db, key: id)?.contextSnapshot
    }
    let deleted = try await dbPool.write { db in
      try TranscriptRecord.deleteOne(db, key: id)
    }
    if deleted, let contextSnapshot {
      DictationContextAttachmentCleanup.removeOwnedFiles(in: contextSnapshot.attachments)
    }
  }

  private func databasePool() throws -> DatabasePool {
    guard let dbPool else {
      throw TranscriptStoreError.initializationFailed(
        initializationErrorDescription ?? "Unknown database initialization error."
      )
    }
    return dbPool
  }

  private func encodedArtifact(_ artifact: TranscriptionArtifact) throws -> String {
    let data = try TranscriptionArtifactCoders.encode(artifact)
    guard let json = String(data: data, encoding: .utf8) else {
      throw TranscriptStoreError.artifactEncodingFailed
    }
    return json
  }

  private func encodedTransformation(_ transformation: TextTransformationCapture) throws -> String {
    let data = try TextTransformationCaptureCoders.encode(transformation)
    guard let json = String(data: data, encoding: .utf8) else {
      throw TranscriptStoreError.artifactEncodingFailed
    }
    return json
  }

  private func encodedContextSnapshot(_ snapshot: DictationContextSnapshot) throws -> String {
    let data = try DictationContextSnapshotCoders.encode(snapshot)
    guard let json = String(data: data, encoding: .utf8) else {
      throw TranscriptStoreError.artifactEncodingFailed
    }
    return json
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
  case artifactEncodingFailed
  case initializationFailed(String)
  case transformationCaptureRequired

  var errorDescription: String? {
    switch self {
    case .applicationSupportDirectoryUnavailable:
      "Application Support is unavailable."
    case .artifactEncodingFailed:
      "The transcription artifact could not be encoded as UTF-8."
    case .initializationFailed(let message):
      "Transcript database could not be opened: \(message)"
    case .transformationCaptureRequired:
      "Processed text requires its transformation capture."
    }
  }
}
