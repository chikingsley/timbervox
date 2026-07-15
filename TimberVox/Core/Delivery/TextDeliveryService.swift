import AppKit
import Carbon.HIToolbox

enum ClipboardRetentionPreference {
  static let keepTranscriptOnClipboardAfterPasteKey = "keepTranscriptOnClipboardAfterPaste"
  static let defaultKeepTranscriptOnClipboardAfterPaste = true

  static var keepTranscriptOnClipboardAfterPaste: Bool {
    let saved = UserDefaults.standard.object(forKey: keepTranscriptOnClipboardAfterPasteKey) as? Bool
    return saved ?? defaultKeepTranscriptOnClipboardAfterPaste
  }
}

/// Puts text on the clipboard, then sends ⌘V to the current focused app.
@MainActor
struct TextDeliveryService {
  func copy(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }

  /// Returns false when pasting isn't possible (no Accessibility permission) —
  /// caller should leave the text on the clipboard instead.
  func paste(_ text: String) async -> Bool {
    guard AccessibilityPermission.isTrusted else { return false }

    let pasteboard = NSPasteboard.general
    let shouldRestorePreviousClipboard =
      !ClipboardRetentionPreference.keepTranscriptOnClipboardAfterPaste
    let snapshot = shouldRestorePreviousClipboard ? PasteboardSnapshot(pasteboard: pasteboard) : nil
    copy(text)

    postCmdV()

    if let snapshot {
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(1200))
        snapshot.restore(to: pasteboard)
      }
    }
    return true
  }

  private func postCmdV() {
    let source = CGEventSource(stateID: .combinedSessionState)
    let commandKey: CGKeyCode = 55
    let vKey = CGKeyCode(kVK_ANSI_V)

    let commandDown = CGEvent(keyboardEventSource: source, virtualKey: commandKey, keyDown: true)
    let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
    vDown?.flags = .maskCommand
    let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
    vUp?.flags = .maskCommand
    let commandUp = CGEvent(keyboardEventSource: source, virtualKey: commandKey, keyDown: false)

    commandDown?.post(tap: .cghidEventTap)
    vDown?.post(tap: .cghidEventTap)
    vUp?.post(tap: .cghidEventTap)
    commandUp?.post(tap: .cghidEventTap)
  }
}

private struct PasteboardSnapshot {
  let items: [[String: Data]]

  init(pasteboard: NSPasteboard) {
    var saved: [[String: Data]] = []
    for item in pasteboard.pasteboardItems ?? [] {
      var itemDict: [String: Data] = [:]
      for type in item.types {
        if let data = item.data(forType: type) {
          itemDict[type.rawValue] = data
        }
      }
      saved.append(itemDict)
    }
    items = saved
  }

  func restore(to pasteboard: NSPasteboard) {
    pasteboard.clearContents()
    for itemDict in items {
      let item = NSPasteboardItem()
      for (type, data) in itemDict {
        item.setData(data, forType: NSPasteboard.PasteboardType(rawValue: type))
      }
      pasteboard.writeObjects([item])
    }
  }
}
