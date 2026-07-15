import AppKit
import SwiftUI

@main
struct TimberVoxApp: App {
  @State private var billing = SubscriptionController.shared
  @State private var dictation: DictationController
  @State private var permissions: PermissionCoordinator
  private let indicator: RecordingIndicatorManager
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @AppStorage("appearance") private var appearanceRaw = AppearanceChoice.automatic.rawValue

  init() {
    #if DEBUG
      if ProcessInfo.processInfo.environment["TIMBERVOX_TEST_HOST"] == "1" {
        NSApplication.shared.setActivationPolicy(.prohibited)
      }
    #endif

    let controller = DictationController()
    _dictation = State(initialValue: controller)
    _permissions = State(initialValue: PermissionCoordinator())
    indicator = RecordingIndicatorManager(dictation: controller)
  }

  var body: some Scene {
    Window("TimberVox", id: "main") {
      Group {
        if shouldShowOnboarding {
          OnboardingView(dictation: dictation, permissions: permissions) {
            hasCompletedOnboarding = true
          }
        } else {
          AppShellView(dictation: dictation, billing: billing, permissions: permissions)
        }
      }
      .preferredColorScheme(
        AppearanceChoice(rawValue: appearanceRaw)?.colorScheme
      )
      .scTooltipProvider()
      .theme(.timberVox)
      .background(WindowChromeConfigurator())
      .task {
        await billing.refresh()
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      ) { _ in
        permissions.refresh()
      }
    }
    .defaultSize(width: 780, height: 560)
    .defaultLaunchBehavior(.presented)
    .windowStyle(.hiddenTitleBar)

    MenuBarExtra {
      MenuBarContent(dictation: dictation)
    } label: {
      Image(systemName: menuIcon)
    }
  }

  private var shouldShowOnboarding: Bool {
    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      if arguments.contains("--show-onboarding") { return true }
      if arguments.contains("--skip-onboarding") { return false }
    #endif
    return !hasCompletedOnboarding
  }

  private var menuIcon: String {
    switch dictation.state {
    case .idle: "waveform"
    case .recording: "record.circle.fill"
    case .transcribing: "ellipsis.circle"
    }
  }
}

private struct MenuBarContent: View {
  let dictation: DictationController
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button("Open TimberVox") {
      openWindow(id: "main")
      NSApp.activate()
    }

    Divider()

    switch dictation.state {
    case .recording:
      Button("Stop Recording (⌥Space)") {
        dictation.stopAndTranscribe()
      }
      Button("Cancel Recording (Esc)") {
        dictation.cancelRecording()
      }
    case .transcribing:
      Text("Transcribing…")
    case .idle:
      Button("Start Recording (⌥Space)") {
        dictation.toggle()
      }
    }

    Divider()

    Button("Quit TimberVox") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}
