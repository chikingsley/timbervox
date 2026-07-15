import Foundation

/// How long captured context attachments (screenshots and clipboard images)
/// stay on disk. Transcripts themselves are never deleted automatically.
enum DictationContextRetentionPreference {
  static let key = "contextAttachmentRetentionDays"
  static let defaultDays = RetentionPeriodOption.oneMonth.rawValue

  static var retentionDays: Int {
    let saved = UserDefaults.standard.object(forKey: key) as? Int
    return saved ?? defaultDays
  }
}

/// Deletes context attachment files older than the retention window. Every
/// file in ContextAttachments is app-created (screen and clipboard captures
/// copied at dictation time), so age alone decides what goes.
enum DictationContextRetentionSweeper {
  @discardableResult
  static func sweep(
    retentionDays: Int = DictationContextRetentionPreference.retentionDays,
    directory: URL? = nil,
    now: Date = .now
  ) -> Int {
    let removedCount = AgedFileSweeper.sweep(
      directory: directory ?? Self.attachmentsDirectory(),
      retentionDays: retentionDays,
      now: now
    )
    if removedCount > 0 {
      TimberVoxLog.dictation.info("Context attachment sweep removed \(removedCount) file(s).")
    }
    return removedCount
  }

  static func attachmentsDirectory() -> URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first?
      .appendingPathComponent("TimberVox/ContextAttachments", isDirectory: true)
  }
}
