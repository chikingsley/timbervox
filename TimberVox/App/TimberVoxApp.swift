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
      _ = Bundle(
        path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle"
      )?.load()
    #endif

    let controller = DictationController()
    _dictation = State(initialValue: controller)
    _permissions = State(initialValue: PermissionCoordinator())
    indicator = RecordingIndicatorManager(dictation: controller)
  }

  var body: some Scene {
    Window("TimberVox", id: "main") {
      Group {
        if isRunningForXcodePreviews {
          // Xcode previews launch the real app as the preview host. Building the full
          // shell there crashes the preview when its window content is replaced, so the
          // host shows nothing and only the previewed view renders.
          Color.clear
        } else if shouldShowPrototype {
          TimberVoxPrototype()
        } else if shouldShowOnboarding {
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

    #if DEBUG
      Window("UI Prototype", id: "prototype") {
        TimberVoxPrototype()
      }
      .defaultSize(
        width: PrototypeLayout.windowWidth,
        height: PrototypeLayout.windowHeight
      )
      .defaultLaunchBehavior(.suppressed)
    #endif

    MenuBarExtra {
      MenuBarContent(dictation: dictation)
    } label: {
      Image(systemName: menuIcon)
    }
  }

  private var isRunningForXcodePreviews: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }

  private var shouldShowPrototype: Bool {
    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      return arguments.contains("--prototype") || arguments.contains("--prototype-modes")
    #else
      false
    #endif
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
