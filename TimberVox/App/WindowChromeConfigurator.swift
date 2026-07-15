import AppKit
import SwiftUI

/// Applies window behavior SwiftUI's scene modifiers do not expose.
struct WindowChromeConfigurator: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    WindowChromeConfigurationView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowChromeConfigurationView: NSView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.standardWindowButton(.zoomButton)?.isHidden = true
  }
}
