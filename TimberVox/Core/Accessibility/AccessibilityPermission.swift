import AppKit
import ApplicationServices

@MainActor
enum AccessibilityPermission {
  static var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  /// Shows the system dialog that offers to open Accessibility settings.
  static func requestPrompt() {
    _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
  }

  static func openSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      )
    else { return }
    NSWorkspace.shared.open(url)
  }
}
