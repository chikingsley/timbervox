import AVFoundation
import Foundation
import GRDB

struct MacWhisperImportResult: Equatable, Sendable {
  var importedRecords: Int
  var skippedRecords: Int
  var copiedAudioFiles: Int
  var missingAudioFiles: Int
}

struct MacWhisperImporter {
  static let importSource = "macwhisper"
  static let modeID = "macwhisper-voice-to-text-parakeet-v3"
  static let modeName = "Voice to text"
  static let modelID = LocalTranscriptionRouteID.parakeetTdtV3.rawValue

  static let voiceToTextMode = DictationMode(
    id: modeID,
    name: modeName,
    audioModelID: "local-nightingale",
    languageCode: nil,
    realtimeEnabled: false,
    diarizationEnabled: false,
    textTransformPreset: .voiceToText,
    textTransformModelID: "mistral-mistral-small-latest"
  )

  private let sourceDatabaseURL: URL
  private let sourceMediaDirectory: URL
  private let destinationMediaDirectory: URL
  private let transcriptStore: TranscriptStore
  private let fileManager: FileManager

  init(
    sourceDatabaseURL: URL,
    sourceMediaDirectory: URL,
    destinationMediaDirectory: URL,
    transcriptStore: TranscriptStore = .shared,
    fileManager: FileManager = .default
  ) {
    self.sourceDatabaseURL = sourceDatabaseURL
    self.sourceMediaDirectory = sourceMediaDirectory
    self.destinationMediaDirectory = destinationMediaDirectory
    self.transcriptStore = transcriptStore
    self.fileManager = fileManager
  }

  static func live() throws -> MacWhisperImporter {
    let applicationSupport = try applicationSupportDirectory()
    let macWhisperDatabase =
      applicationSupport
      .appendingPathComponent("MacWhisper/Database", isDirectory: true)
    let timberVox = applicationSupport.appendingPathComponent("TimberVox", isDirectory: true)
    return MacWhisperImporter(
      sourceDatabaseURL: macWhisperDatabase.appendingPathComponent("main.sqlite"),
      sourceMediaDirectory: macWhisperDatabase.appendingPathComponent("ExternalMedia", isDirectory: true),
      destinationMediaDirectory:
        timberVox
        .appendingPathComponent("Recordings/Imported/MacWhisper", isDirectory: true)
    )
  }

  func run() throws -> MacWhisperImportResult {
    guard fileManager.fileExists(atPath: sourceDatabaseURL.path) else {
      throw MacWhisperImportError.sourceDatabaseUnavailable(sourceDatabaseURL.path)
    }
    try fileManager.createDirectory(
      at: destinationMediaDirectory,
      withIntermediateDirectories: true
    )

    var configuration = Configuration()
    configuration.readonly = true
    let sourceQueue = try DatabaseQueue(
      path: sourceDatabaseURL.path,
      configuration: configuration
    )
    let sourceRecords = try sourceQueue.read { database in
      try MacWhisperSourceRecord.fetchAll(database, sql: Self.sourceQuery)
    }

    var result = MacWhisperImportResult(
      importedRecords: 0,
      skippedRecords: 0,
      copiedAudioFiles: 0,
      missingAudioFiles: 0
    )
    for source in sourceRecords {
      let audio = try importAudio(filename: source.mediaFilename)
      let imported = try transcriptStore.importRecord(
        TranscriptImport(
          text: source.text,
          createdAt: source.createdAt,
          duration: audio.duration,
          model: Self.modelID,
          modeID: Self.modeID,
          modeName: Self.modeName,
          audioPath: audio.url?.path,
          provider: "MacWhisper",
          sourceApplicationName: source.applicationName,
          sourceApplicationBundleIdentifier: source.applicationBundleIdentifier,
          importSource: Self.importSource,
          importExternalID: source.externalID
        )
      )
      if imported == nil {
        result.skippedRecords += 1
      } else {
        result.importedRecords += 1
        if audio.wasCopied { result.copiedAudioFiles += 1 }
        if audio.url == nil { result.missingAudioFiles += 1 }
      }
    }
    return result
  }

  private func importAudio(filename: String?) throws -> ImportedAudio {
    guard let filename, !filename.isEmpty else {
      return ImportedAudio(url: nil, duration: 0, wasCopied: false)
    }
    let sourceURL = sourceMediaDirectory.appendingPathComponent(filename)
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      return ImportedAudio(url: nil, duration: 0, wasCopied: false)
    }
    let destinationURL = destinationMediaDirectory.appendingPathComponent(filename)
    let wasCopied = !fileManager.fileExists(atPath: destinationURL.path)
    if wasCopied {
      try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
    return ImportedAudio(
      url: destinationURL,
      duration: Self.audioDuration(at: destinationURL),
      wasCopied: wasCopied
    )
  }

  private static func audioDuration(at url: URL) -> TimeInterval {
    guard
      let file = try? AVAudioFile(forReading: url),
      file.processingFormat.sampleRate > 0
    else {
      return 0
    }
    return Double(file.length) / file.processingFormat.sampleRate
  }

  private static func applicationSupportDirectory() throws -> URL {
    guard
      let directory = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else {
      throw MacWhisperImportError.applicationSupportDirectoryUnavailable
    }
    return directory
  }

  private static let sourceQuery = """
    SELECT lower(hex(d.id)) AS externalID,
           d.dateCreated AS createdAt,
           d.transcribedText AS text,
           d.targetAppLocalizedName AS applicationName,
           d.targetAppBundleID AS applicationBundleIdentifier,
           m.filename AS mediaFilename
      FROM dictation d
      LEFT JOIN mediafile m ON m.id = d.mediaFileID
     WHERE d.dateDeleted IS NULL
       AND d.transcriptionDidSucceed != 0
       AND length(trim(d.transcribedText)) > 0
     ORDER BY d.dateCreated
    """
}

private struct ImportedAudio {
  var url: URL?
  var duration: TimeInterval
  var wasCopied: Bool
}

private struct MacWhisperSourceRecord: FetchableRecord, Decodable {
  var externalID: String
  var createdAt: Date
  var text: String
  var applicationName: String?
  var applicationBundleIdentifier: String?
  var mediaFilename: String?
}

enum MacWhisperImportError: LocalizedError {
  case applicationSupportDirectoryUnavailable
  case sourceDatabaseUnavailable(String)

  var errorDescription: String? {
    switch self {
    case .applicationSupportDirectoryUnavailable:
      "Application Support is unavailable."
    case .sourceDatabaseUnavailable(let path):
      "The MacWhisper database is unavailable at \(path)."
    }
  }
}
