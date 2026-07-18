import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
  static let timberVoxMode = UTType(
    exportedAs: "studio.peacockery.timbervox.mode",
    conformingTo: .json
  )
}

struct TimberVoxModeFile: Codable, Equatable, Sendable {
  static let currentSchemaVersion = 1
  static let maximumFileBytes = 1_048_576

  let schemaVersion: Int
  let exportedAt: Date
  let mode: DictationMode

  init(mode: DictationMode, exportedAt: Date = .now) {
    schemaVersion = Self.currentSchemaVersion
    self.exportedAt = exportedAt
    self.mode = mode
  }

  func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  static func decode(_ data: Data) throws -> TimberVoxModeFile {
    guard data.count <= maximumFileBytes else {
      throw TimberVoxModeFileError.fileTooLarge
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let file = try decoder.decode(Self.self, from: data)
    guard file.schemaVersion == currentSchemaVersion else {
      throw TimberVoxModeFileError.unsupportedSchema(file.schemaVersion)
    }
    guard !file.mode.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw TimberVoxModeFileError.invalidMode("The mode name is empty.")
    }
    guard file.mode.name.count <= 120 else {
      throw TimberVoxModeFileError.invalidMode("The mode name is too long.")
    }
    guard file.mode.customTextTransformInstructions.count <= 50_000 else {
      throw TimberVoxModeFileError.invalidMode("The custom instructions are too long.")
    }
    guard file.mode.activationBundleIdentifiers.count <= 200 else {
      throw TimberVoxModeFileError.invalidMode("The mode contains too many application rules.")
    }
    return file
  }
}

enum TimberVoxModeFileError: LocalizedError, Equatable {
  case fileTooLarge
  case invalidMode(String)
  case unsupportedSchema(Int)

  var errorDescription: String? {
    switch self {
    case .fileTooLarge:
      "The mode file is larger than 1 MB."
    case .invalidMode(let reason):
      "The mode file is invalid. \(reason)"
    case .unsupportedSchema(let version):
      "This mode file uses unsupported schema version \(version)."
    }
  }
}

struct TimberVoxModeTransfer: Transferable, Sendable {
  let file: TimberVoxModeFile

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .timberVoxMode) { transfer in
      try transfer.file.encoded()
    }
    .suggestedFileName { transfer in
      "\(sanitizedFileName(transfer.file.mode.name)).timbervoxmode"
    }
  }

  private static func sanitizedFileName(_ name: String) -> String {
    let invalid = CharacterSet(charactersIn: "/:\\")
    let parts = name.components(separatedBy: invalid)
    let result = parts.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
    return result.isEmpty ? "TimberVox Mode" : result
  }
}
