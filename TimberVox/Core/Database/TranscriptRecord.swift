import Foundation
import GRDB

struct TranscriptRecord: Identifiable, Codable, Equatable, Sendable, FetchableRecord,
  MutablePersistableRecord
{
  static let databaseTableName = "transcripts"

  var id: Int64?
  var text: String
  var rawText: String?
  var createdAt: Date
  var durationSeconds: Double
  var wordCount: Int = 0
  var model: String
  var modeID: String?
  var modeName: String?
  var audioPath: String?
  var provider: String?
  var status: TranscriptRecordStatus
  var errorCode: String?
  var errorMessage: String?
  var wallLatencyMs: Double?
  var legacyProviderLatencyMs: Double?
  var language: String?
  var transformPreset: String?
  var transformModel: String?
  var transformationJSON: String?
  var transcriptionArtifactJSON: String?
  var contextSnapshotJSON: String?
  var legacySegmentsJSON: String?
  var sourceApplicationName: String?
  var sourceApplicationBundleIdentifier: String?
  var importSource: String?
  var importExternalID: String?

  var artifact: TranscriptionArtifact? {
    guard
      let transcriptionArtifactJSON,
      let data = transcriptionArtifactJSON.data(using: .utf8)
    else { return nil }
    do {
      return try TranscriptionArtifactCoders.decode(data)
    } catch {
      TimberVoxLog.persistence.error(
        "Stored transcription artifact could not be decoded: \(error.localizedDescription)"
      )
      return nil
    }
  }

  var transformation: TextTransformationCapture? {
    guard
      let transformationJSON,
      let data = transformationJSON.data(using: .utf8)
    else { return nil }
    do {
      return try TextTransformationCaptureCoders.decode(data)
    } catch {
      TimberVoxLog.persistence.error(
        "Stored text transformation could not be decoded: \(error.localizedDescription)"
      )
      return nil
    }
  }

  mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}
