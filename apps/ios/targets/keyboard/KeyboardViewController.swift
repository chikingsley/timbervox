import Combine
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
  private let model = KeyboardModel()
  private var hostingController: UIHostingController<KeyboardRootView>?
  private var pollTimer: Timer?
  private var lastTranscriptRevision = -1

  override func viewDidLoad() {
    super.viewDidLoad()
    model.controller = self
    model.proxy = textDocumentProxy
    installKeyboard()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    model.controller = self
    model.proxy = textDocumentProxy
    model.hasFullAccess = hasFullAccess
    model.needsGlobe = needsInputModeSwitchKey
    KeyboardBridge.set(true, for: .keyboardSeen)
    KeyboardBridge.set(hasFullAccess, for: .keyboardHasFullAccess)
    model.refreshBridgeState()
    startPolling()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    pollTimer?.invalidate()
    pollTimer = nil
  }

  override func textDidChange(_ textInput: UITextInput?) {
    super.textDidChange(textInput)
    model.proxy = textDocumentProxy
    model.refreshCapitalization()
  }

  private func installKeyboard() {
    let keyboard = KeyboardRootView(model: model)
    let hosting = UIHostingController(rootView: keyboard)
    hosting.view.backgroundColor = .clear
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    if #available(iOS 16.0, *) {
      hosting.sizingOptions = []
    }
    addChild(hosting)
    view.addSubview(hosting.view)
    hosting.didMove(toParent: self)
    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      view.heightAnchor.constraint(equalToConstant: 292),
    ])
    hostingController = hosting
  }

  private func startPolling() {
    pollTimer?.invalidate()
    pollTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
      self?.pollBridge()
    }
    pollBridge()
  }

  private func pollBridge() {
    model.refreshBridgeState()
    let revision = KeyboardBridge.integer(for: .transcriptRevision)
    guard revision != lastTranscriptRevision else { return }
    lastTranscriptRevision = revision
    guard let text = KeyboardBridge.string(for: .pendingTranscript), !text.isEmpty else { return }
    textDocumentProxy.insertText(model.textForInsertion(text))
    KeyboardBridge.remove(.pendingTranscript)
    model.partialTranscript = ""
    model.refreshCapitalization()
  }
}

@MainActor
final class KeyboardModel: ObservableObject {
  @Published var predictions = ["TimberVox", "voice", "keyboard"]
  @Published var partialTranscript = ""
  @Published var sessionActive = false
  @Published var recordingRequested = false
  @Published var hasFullAccess = false
  @Published var needsGlobe = true
  @Published var shifted = false

  weak var controller: UIInputViewController?
  weak var proxy: UITextDocumentProxy?

  let decoder = GeometricSwipeDecoder()

  func refreshBridgeState() {
    sessionActive = KeyboardBridge.bool(for: .sessionActive)
    recordingRequested = KeyboardBridge.bool(for: .recordingRequested)
    partialTranscript = KeyboardBridge.string(for: .partialTranscript) ?? ""
    hasFullAccess = controller?.hasFullAccess ?? false
  }

  func refreshCapitalization() {
    guard let context = proxy?.documentContextBeforeInput else {
      shifted = true
      return
    }
    shifted = context.isEmpty || context.last?.isNewline == true || context.hasSuffix(". ")
  }

  func insert(_ text: String) {
    proxy?.insertText(shifted ? text.uppercased() : text)
    shifted = false
  }

  func acceptPrediction(_ prediction: String) {
    proxy?.insertText(textForInsertion(prediction) + " ")
    predictions = ["TimberVox", "voice", "keyboard"]
  }

  func deleteBackward() {
    proxy?.deleteBackward()
    refreshCapitalization()
  }

  func insertSpace() {
    proxy?.insertText(" ")
  }

  func insertReturn() {
    proxy?.insertText("\n")
    shifted = true
  }

  func toggleShift() {
    shifted.toggle()
  }

  func advanceKeyboard() {
    controller?.advanceToNextInputMode()
  }

  func toggleDictation() {
    guard hasFullAccess else {
      predictions = ["Enable", "Full Access", "in Settings"]
      return
    }
    guard sessionActive else {
      predictions = ["Opening", "TimberVox", "session"]
      openPersonalSession()
      return
    }
    let next = !recordingRequested
    KeyboardBridge.set(next, for: .recordingRequested)
    KeyboardBridge.set(KeyboardBridge.integer(for: .requestRevision) + 1, for: .requestRevision)
    recordingRequested = next
    if next {
      predictions = ["Listening…", "Speak", "naturally"]
    }
  }

  func handleSwipe(points: [CGPoint], layout: KeyLayout) {
    let results = decoder.predictions(for: points, layout: layout)
    guard let first = results.first else { return }
    predictions = Array(results.prefix(3))
    proxy?.insertText(textForInsertion(shifted ? first.capitalized : first) + " ")
    shifted = false
  }

  func textForInsertion(_ text: String) -> String {
    guard let last = proxy?.documentContextBeforeInput?.last,
          (last.isLetter || last.isNumber),
          let first = text.first,
          first.isLetter || first.isNumber
    else { return text }
    return " " + text
  }

  private func openPersonalSession() {
    #if DEBUG
      guard let url = URL(string: "timbervox://session") else { return }
      let selector = NSSelectorFromString("openURL:")
      var responder: UIResponder? = controller
      while let current = responder {
        if current.responds(to: selector) {
          _ = current.perform(selector, with: url)
          return
        }
        responder = current.next
      }
      predictions = ["Open", "TimberVox", "manually"]
    #else
      predictions = ["Start session", "in TimberVox", "or Shortcut"]
    #endif
  }
}

private enum BridgeKey: String {
  case keyboardSeen
  case keyboardHasFullAccess
  case sessionActive
  case recordingRequested
  case requestRevision
  case transcriptRevision
  case pendingTranscript
  case partialTranscript
}

private enum KeyboardBridge {
  static let group = "group.com.chiejimofor.timbervox"

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: group)
  }

  static func bool(for key: BridgeKey) -> Bool {
    defaults?.bool(forKey: key.rawValue) ?? false
  }

  static func integer(for key: BridgeKey) -> Int {
    defaults?.integer(forKey: key.rawValue) ?? 0
  }

  static func string(for key: BridgeKey) -> String? {
    defaults?.string(forKey: key.rawValue)
  }

  static func set(_ value: Bool, for key: BridgeKey) {
    defaults?.set(value, forKey: key.rawValue)
  }

  static func set(_ value: Int, for key: BridgeKey) {
    defaults?.set(value, forKey: key.rawValue)
  }

  static func remove(_ key: BridgeKey) {
    defaults?.removeObject(forKey: key.rawValue)
  }
}
