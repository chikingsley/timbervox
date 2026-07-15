import GRDB

enum TranscriptRecordStatus: String, Codable, Equatable, Sendable {
  case failed
  case noSpeech = "no_speech"
  case succeeded
}

extension TranscriptRecordStatus: DatabaseValueConvertible {
  var databaseValue: DatabaseValue {
    rawValue.databaseValue
  }

  static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
    String.fromDatabaseValue(dbValue).flatMap(Self.init(rawValue:))
  }
}
