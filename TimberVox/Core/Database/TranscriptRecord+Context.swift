import Foundation

extension TranscriptRecord {
  var contextSnapshot: DictationContextSnapshot? {
    guard
      let contextSnapshotJSON,
      let data = contextSnapshotJSON.data(using: .utf8)
    else { return nil }
    do {
      return try DictationContextSnapshotCoders.decode(data)
    } catch {
      TimberVoxLog.persistence.error(
        "Stored dictation context could not be decoded: \(error.localizedDescription)"
      )
      return nil
    }
  }
}
