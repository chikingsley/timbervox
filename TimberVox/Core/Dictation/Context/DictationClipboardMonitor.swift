import AppKit
import Foundation
import UniformTypeIdentifiers

struct DictationClipboardSnapshot: Sendable {
  var changeCount: Int
  var text: String?
  var attachments: [DictationContextAttachment]
  var capturedAt: Date
}

@MainActor
final class DictationClipboardMonitor {
  private let pasteboard: NSPasteboard
  private let attachmentDirectory: URL?
  private let limits: DictationContextCaptureLimits
  private var lastChangeCount: Int
  private var snapshots: [DictationClipboardSnapshot] = []
  private var task: Task<Void, Never>?

  init(
    pasteboard: NSPasteboard = .general,
    attachmentDirectory: URL?,
    limits: DictationContextCaptureLimits = .init()
  ) {
    self.pasteboard = pasteboard
    self.attachmentDirectory = attachmentDirectory
    self.limits = limits
    lastChangeCount = pasteboard.changeCount
  }

  func start() {
    guard task == nil else { return }
    task = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(300))
        self?.captureIfChanged()
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
  }

  func captureIfChanged(capturedAt: Date = .now, force: Bool = false) {
    let changeCount = pasteboard.changeCount
    guard force || changeCount != lastChangeCount else {
      prune(now: capturedAt)
      return
    }
    lastChangeCount = changeCount
    let snapshot = DictationClipboardSnapshot(
      changeCount: changeCount,
      text: pasteboard.string(forType: .string),
      attachments: pasteboard.pasteboardItems?.flatMap {
        attachments(from: $0, capturedAt: capturedAt)
      } ?? [],
      capturedAt: capturedAt
    )
    snapshots.append(snapshot)
    prune(now: capturedAt)
  }

  func snapshots(startedAt: Date, through now: Date) -> [DictationClipboardSnapshot] {
    snapshots.filter {
      limits.includesPreRecordingItem(capturedAt: $0.capturedAt, recordingStartedAt: startedAt)
        || ($0.capturedAt > startedAt && $0.capturedAt <= now)
    }
  }

  private func prune(now: Date) {
    let expired = snapshots.filter {
      !limits.shouldRetain(capturedAt: $0.capturedAt, now: now)
    }
    DictationContextAttachmentCleanup.removeOwnedFiles(
      in: expired.flatMap(\.attachments)
    )
    snapshots.removeAll { !limits.shouldRetain(capturedAt: $0.capturedAt, now: now) }
  }

  private func attachments(
    from item: NSPasteboardItem,
    capturedAt: Date
  ) -> [DictationContextAttachment] {
    var result: [DictationContextAttachment] = []
    if let rawURL = item.string(forType: .fileURL), let url = URL(string: rawURL) {
      result.append(
        DictationContextAttachment(
          kind: .clipboardFile,
          uniformTypeIdentifier: UTType.fileURL.identifier,
          filename: url.lastPathComponent,
          localPath: url.path,
          capturedAt: capturedAt
        )
      )
    }
    for type in [NSPasteboard.PasteboardType.png, .tiff] {
      guard let data = item.data(forType: type), let attachmentDirectory else { continue }
      let fileExtension = type == .png ? "png" : "tiff"
      let filename = "clipboard-\(UUID().uuidString).\(fileExtension)"
      let url = attachmentDirectory.appendingPathComponent(filename)
      do {
        try data.write(to: url, options: .atomic)
        result.append(
          DictationContextAttachment(
            kind: .clipboardImage,
            uniformTypeIdentifier: type.rawValue,
            filename: filename,
            byteCount: data.count,
            localPath: url.path,
            capturedAt: capturedAt
          )
        )
      } catch {
        TimberVoxLog.dictation.error("Clipboard image capture failed: \(error.localizedDescription)")
      }
      break
    }
    return result
  }
}
