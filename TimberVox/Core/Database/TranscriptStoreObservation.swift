import Foundation
import GRDB

/// Everything the Home pane shows: whole-history stats plus the recent-activity rows.
struct HomeDictationOverview: Equatable, Sendable {
  static let recentRecordLimit = 5

  var dictationCount: Int
  var totalWords: Int
  var totalDurationSeconds: Double
  var recentRecords: [TranscriptRecord]

  static let empty = HomeDictationOverview(
    dictationCount: 0,
    totalWords: 0,
    totalDurationSeconds: 0,
    recentRecords: []
  )
}

/// One page of History rows plus the total match count.
struct HistoryPage: Equatable, Sendable {
  var records: [TranscriptRecord]
  var totalCount: Int
  var queryMilliseconds: Double

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.records == rhs.records && lhs.totalCount == rhs.totalCount
  }
}

extension TranscriptStore {
  /// Columns light enough for list rows — everything except the JSON payloads.
  fileprivate static let listColumns: [Column] = [
    Column("id"), Column("text"), Column("rawText"), Column("createdAt"),
    Column("durationSeconds"), Column("wordCount"), Column("model"), Column("modeID"),
    Column("modeName"), Column("audioPath"), Column("provider"), Column("status"),
    Column("errorCode"), Column("errorMessage"), Column("wallLatencyMs"),
    Column("legacyProviderLatencyMs"), Column("language"), Column("transformPreset"),
    Column("transformModel"), Column("sourceApplicationName"),
    Column("sourceApplicationBundleIdentifier"), Column("importSource"),
    Column("importExternalID"),
  ]

  static func fetchHomeOverview(_ db: Database) throws -> HomeDictationOverview {
    let succeeded = TranscriptRecordStatus.succeeded
    guard
      let totals = try Row.fetchOne(
        db,
        sql: """
          SELECT COUNT(*) AS dictationCount,
                 IFNULL(SUM(wordCount), 0) AS totalWords,
                 IFNULL(SUM(durationSeconds), 0) AS totalDurationSeconds
          FROM transcripts
          WHERE status = ?
          """,
        arguments: [succeeded]
      )
    else {
      return .empty
    }
    let recentRecords =
      try TranscriptRecord
      .select(listColumns)
      .filter(Column("status") == succeeded)
      .order(Column("createdAt").desc)
      .limit(HomeDictationOverview.recentRecordLimit)
      .fetchAll(db)
    let dictationCount: Int = totals["dictationCount"]
    let totalWords: Int = totals["totalWords"]
    let totalDurationSeconds: Double = totals["totalDurationSeconds"]
    return HomeDictationOverview(
      dictationCount: dictationCount,
      totalWords: totalWords,
      totalDurationSeconds: totalDurationSeconds,
      recentRecords: recentRecords
    )
  }

  static func fetchHistoryPage(
    _ db: Database,
    query: String,
    limit: Int
  ) throws -> HistoryPage {
    let (page, milliseconds) = try NavigationPerformance.measureHistoryQuery {
      () throws -> (records: [TranscriptRecord], totalCount: Int) in
      let base =
        query.isEmpty
        ? TranscriptRecord.all()
        : TranscriptRecord.filter(Column("text").like("%\(query)%"))
      let records =
        try base
        .select(listColumns)
        .order(Column("createdAt").desc)
        .limit(limit)
        .fetchAll(db)
      let totalCount = try base.fetchCount(db)
      return (records, totalCount)
    }
    return HistoryPage(
      records: page.records,
      totalCount: page.totalCount,
      queryMilliseconds: milliseconds
    )
  }
}
