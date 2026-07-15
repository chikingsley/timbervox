import Foundation

/// The retention windows offered anywhere Settings keeps files for a while.
enum RetentionPeriodOption: Int, CaseIterable, Identifiable {
  case oneWeek = 7
  case oneMonth = 30
  case threeMonths = 90
  case forever = 0

  var id: Int { rawValue }

  var label: String {
    switch self {
    case .oneWeek: "1 week"
    case .oneMonth: "30 days"
    case .threeMonths: "90 days"
    case .forever: "Forever"
    }
  }
}

/// Deletes files in a directory once they age past the retention window.
/// Only safe for directories whose every file is app-created.
enum AgedFileSweeper {
  @discardableResult
  static func sweep(directory: URL?, retentionDays: Int, now: Date = .now) -> Int {
    guard retentionDays > 0, let directory else { return 0 }
    let cutoff = now.addingTimeInterval(-TimeInterval(retentionDays) * 24 * 60 * 60)
    let fileManager = FileManager.default
    guard
      let files = try? fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.contentModificationDateKey]
      )
    else { return 0 }
    var removedCount = 0
    for file in files {
      guard
        let modifiedAt = try? file.resourceValues(forKeys: [.contentModificationDateKey])
          .contentModificationDate,
        modifiedAt < cutoff
      else { continue }
      do {
        try fileManager.removeItem(at: file)
        removedCount += 1
      } catch {
        TimberVoxLog.persistence.error(
          "Retention sweep could not remove \(file.lastPathComponent): \(error.localizedDescription)"
        )
      }
    }
    return removedCount
  }

  static func directorySizeBytes(_ directory: URL?) -> Int64 {
    guard
      let directory,
      let files = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]
      )
    else { return 0 }
    return files.reduce(into: Int64(0)) { total, file in
      let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
      total += Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
    }
  }
}

/// How long recorded dictation audio stays in Recordings/. Defaults to
/// Forever because deleting audio removes playback and re-transcribe for
/// those History rows; cleanup is opt-in.
enum RecordingRetentionPreference {
  static let key = "recordingRetentionDays"
  static let defaultDays = RetentionPeriodOption.forever.rawValue

  static var retentionDays: Int {
    let saved = UserDefaults.standard.object(forKey: key) as? Int
    return saved ?? defaultDays
  }
}

enum RecordingRetentionSweeper {
  @discardableResult
  static func sweep(
    retentionDays: Int = RecordingRetentionPreference.retentionDays,
    directory: URL? = nil,
    now: Date = .now
  ) -> Int {
    let removedCount = AgedFileSweeper.sweep(
      directory: directory ?? Self.recordingsDirectory(),
      retentionDays: retentionDays,
      now: now
    )
    if removedCount > 0 {
      TimberVoxLog.persistence.info("Recording sweep removed \(removedCount) audio file(s).")
    }
    return removedCount
  }

  static func recordingsDirectory() -> URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first?
      .appendingPathComponent("TimberVox/Recordings", isDirectory: true)
  }
}
