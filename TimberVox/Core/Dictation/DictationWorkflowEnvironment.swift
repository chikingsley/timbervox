import AppKit
import Foundation

struct SourceApplication {
  var name: String
  var bundleIdentifier: String?
}

enum DictationWorkflowEnvironment {
  static func newRecordingURL() throws -> URL {
    guard
      let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else {
      throw DictationWorkflowError.applicationSupportDirectoryUnavailable
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let name = "Recording-\(formatter.string(from: .now)).wav"
    return applicationSupport.appendingPathComponent("TimberVox/Recordings/\(name)")
  }

  static func frontmostApplication() -> SourceApplication? {
    guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
    guard application.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
    return SourceApplication(
      name: application.localizedName ?? application.bundleIdentifier ?? "Unknown Application",
      bundleIdentifier: application.bundleIdentifier
    )
  }
}
