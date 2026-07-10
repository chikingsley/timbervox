import AppKit
import SwiftUI

struct PrototypeWindowConfiguration: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    PrototypeWindowConfigurationView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class PrototypeWindowConfigurationView: NSView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.standardWindowButton(.zoomButton)?.isHidden = true
  }
}
