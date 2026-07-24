import AppIntents
import ExpoModulesCore
import Foundation
import UIKit

public final class TimberVoxSystemModule: Module {
  public func definition() -> ModuleDefinition {
    Name("TimberVoxSystem")

    Function("startKeyboardStatusObserver") {
      KeyboardStatusObserver.shared.start()
    }

    Function("getKeyboardStatus") {
      KeyboardStatusObserver.shared.status()
    }

    Function("markKeyboardVerificationRequired") {
      KeyboardStatusObserver.shared.markVerificationRequired()
    }

    Function("requestNativeSessionStop") {
      NativeSessionBridge.requestStop()
    }

    Function("getNativeResultOutbox") {
      NativeResultOutbox.items()
    }

    Function("acknowledgeNativeResult") { (filename: String) in
      NativeResultOutbox.acknowledge(filename: filename)
    }

    Function("getShortcutDiagnostics") {
      ShortcutDiagnostics.exportJSON()
    }

    Function("clearShortcutDiagnostics") {
      ShortcutDiagnostics.clear()
    }

    // Presents the bundled signed wrapper shortcut so the user can add it to
    // their library with one tap. iOS has no direct import API for local
    // shortcut files, so the share sheet's Shortcuts row is the entry point.
    AsyncFunction("presentShortcutImport") { (promise: Promise) in
      DispatchQueue.main.async {
        guard
          let url = Bundle.main.url(
            forResource: "Toggle TimberVox Dictation",
            withExtension: "shortcut"
          ),
          let viewController = self.appContext?.utilities?.currentViewController()
        else {
          promise.resolve(false)
          return
        }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        viewController.present(activity, animated: true)
        promise.resolve(true)
      }
    }

    View(TimberVoxShortcutsButton.self) {}
  }
}

private enum NativeSessionBridge {
  private static let group = "group.studio.peacockery.timbervox"

  static func requestStop() {
    guard let defaults = UserDefaults(suiteName: group) else { return }
    defaults.set(true, forKey: "sessionStopRequested")
    defaults.set(defaults.integer(forKey: "sessionRevision") + 1, forKey: "sessionRevision")
    defaults.synchronize()
  }
}

private enum NativeResultOutbox {
  private static let group = "group.studio.peacockery.timbervox"

  static func items() -> [[String: String]] {
    guard let directory = directory() else { return [] }
    let urls =
      (try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )) ?? []
    return
      urls
      .filter { $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
      .compactMap { url in
        guard let json = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return ["filename": url.lastPathComponent, "json": json]
      }
  }

  static func acknowledge(filename: String) {
    guard filename == URL(fileURLWithPath: filename).lastPathComponent,
      filename.hasSuffix(".json"),
      let directory = directory()
    else { return }
    try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
  }

  private static func directory() -> URL? {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: group
      )
    else { return nil }
    let directory = container.appendingPathComponent("NativeResultOutbox", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}

private enum ShortcutDiagnostics {
  private static let group = "group.studio.peacockery.timbervox"

  static func exportJSON() -> String {
    let events = eventURLs().compactMap { url -> [String: Any]? in
      guard let data = try? Data(contentsOf: url),
        let object = try? JSONSerialization.jsonObject(with: data),
        let event = object as? [String: Any]
      else { return nil }
      return event
    }
    let payload: [String: Any] = [
      "events": events,
      "exportedAt": ISO8601DateFormatter().string(from: Date()),
      "schemaVersion": 1,
    ]
    guard JSONSerialization.isValidJSONObject(payload),
      let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
      let json = String(data: data, encoding: .utf8)
    else {
      return #"{"events":[],"exportedAt":"","schemaVersion":1}"#
    }
    return json
  }

  static func clear() {
    for url in eventURLs() {
      try? FileManager.default.removeItem(at: url)
    }
  }

  private static func eventURLs() -> [URL] {
    guard let directory = directory() else { return [] }
    return
      ((try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )) ?? [])
      .filter { $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  private static func directory() -> URL? {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: group
      )
    else { return nil }
    let directory = container.appendingPathComponent("ShortcutDiagnostics", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}

private final class KeyboardStatusObserver: @unchecked Sendable {
  static let shared = KeyboardStatusObserver()

  private static let group = "group.studio.peacockery.timbervox"
  private static let fullAccessName = "studio.peacockery.timbervox.keyboard.full-access"
  private static let restrictedName = "studio.peacockery.timbervox.keyboard.restricted"
  private var started = false

  private init() {}

  func start() {
    guard !started else { return }
    started = true
    let observer = Unmanaged.passUnretained(self).toOpaque()
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      observer,
      keyboardStatusCallback,
      Self.fullAccessName as CFString,
      nil,
      .deliverImmediately
    )
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      observer,
      keyboardStatusCallback,
      Self.restrictedName as CFString,
      nil,
      .deliverImmediately
    )
  }

  fileprivate func record(notificationName: String) {
    guard let defaults = UserDefaults(suiteName: Self.group) else { return }
    defaults.set(true, forKey: "keyboardSeen")
    defaults.set(notificationName == Self.fullAccessName, forKey: "keyboardHasFullAccess")
    defaults.set(false, forKey: "keyboardVerificationRequired")
    let revision = defaults.integer(forKey: "keyboardStatusRevision")
    defaults.set(revision + 1, forKey: "keyboardStatusRevision")
    defaults.synchronize()
  }

  func status() -> [String: Bool] {
    guard let defaults = UserDefaults(suiteName: Self.group) else {
      return [
        "keyboardSeen": false,
        "fullAccess": false,
        "verificationRequired": true,
      ]
    }
    defaults.synchronize()
    return [
      "keyboardSeen": defaults.bool(forKey: "keyboardSeen"),
      "fullAccess": defaults.bool(forKey: "keyboardHasFullAccess"),
      "verificationRequired": defaults.bool(forKey: "keyboardVerificationRequired"),
    ]
  }

  func markVerificationRequired() {
    guard let defaults = UserDefaults(suiteName: Self.group) else { return }
    defaults.set(true, forKey: "keyboardVerificationRequired")
    defaults.synchronize()
  }
}

private let keyboardStatusCallback: CFNotificationCallback = {
  _, observer, name, _, _ in
  guard let observer, let name else { return }
  let statusObserver = Unmanaged<KeyboardStatusObserver>.fromOpaque(observer).takeUnretainedValue()
  statusObserver.record(notificationName: name.rawValue as String)
}

final class TimberVoxShortcutsButton: ExpoView {
  private let shortcutsButton = ShortcutsUIButton(style: .automatic)

  required init(appContext: AppContext? = nil) {
    super.init(appContext: appContext)
    clipsToBounds = true
    isAccessibilityElement = false
    shortcutsButton.accessibilityIdentifier = "timbervox-shortcuts-button"
    shortcutsButton.accessibilityLabel = "Open TimberVox Shortcuts"
    addSubview(shortcutsButton)
    accessibilityElements = [shortcutsButton]
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    shortcutsButton.frame = bounds
  }
}
