import SwiftUI
import TimberVoxCore

struct ConfigurationPane: View {
  enum ShortcutSlot {
    case pushToTalk
    case pasteLastTranscript
    case hotMicPaste
    case hotMicDump
  }

  @Bindable var store: SettingsStore
  let microphonePermission: PermissionStatus
  let accessibilityPermission: PermissionStatus
  let screenCapturePermission: PermissionStatus
  let updates: CheckForUpdatesViewModel

  init(
    store: SettingsStore,
    microphonePermission: PermissionStatus,
    accessibilityPermission: PermissionStatus,
    screenCapturePermission: PermissionStatus,
    updates: CheckForUpdatesViewModel = .shared
  ) {
    self.store = store
    self.microphonePermission = microphonePermission
    self.accessibilityPermission = accessibilityPermission
    self.screenCapturePermission = screenCapturePermission
    self.updates = updates
  }

  @State private var route: ConfigurationRoute = .main

  private var theme: ConfigurationThemeChoice {
    switch store.timberVoxSettings.appearancePreference {
    case .light: .light
    case .dark: .dark
    case .automatic: .automatic
    }
  }

  private var appVersion: String {
    let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    return "\(short) (\(build))"
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Pane {
        switch route {
        case .main:
          mainContent
        case .advanced:
          advancedContent
        }
      }
      .id(route == .main ? "configuration-main" : "configuration-advanced")
    }
  }

  private var header: some View {
    Header(control: headerControl) {
      if route == .main {
        ConfigurationHeaderPill(icon: "circle.lefthalf.filled", text: theme.label)
      }
    }
  }

  private var headerControl: HeaderControl {
    if route == .main {
      .sidebarToggle
    } else {
      .back {
        route = .main
      }
    }
  }

  private var mainContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      appearanceSection
      hotMicSection
      shortcutsSection
      applicationSection
      permissionsSection
      updatesSection
      advancedEntryRow
    }
  }

  private var advancedContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      advancedApplicationSection
      advancedTextInputSection
    }
  }
}

private extension ConfigurationPane {
  private var appearanceSection: some View {
    PaneSection(title: "Appearance") {
      SettingsCard {
        ConfigurationVisualRow(title: "Theme") {
          ConfigurationVisualChoiceGroup {
            ForEach(ConfigurationThemeChoice.allCases) { option in
              ConfigurationVisualChoice(label: option.label, selected: theme == option) {
                store.timberVoxSettings.appearancePreference = option.preference
              } preview: {
                ConfigurationThemeThumbnail(choice: option)
              }
            }
          }
        }

      }
    }
  }

  private var applicationSection: some View {
    PaneSection(title: "Application") {
      SettingsCard {
        SettingsToggleRow(
          icon: "power",
          title: "Launch on login",
          hint: "If enabled, the Application will start when you log in to your Mac.",
          isOn: Binding(
            get: { store.timberVoxSettings.openOnLogin },
            set: { store.toggleOpenOnLogin($0) }
          )
        )
        ConfigurationMenuRow(
          icon: "clock.arrow.circlepath",
          title: "Keep recordings for",
          hint: "Sets the length of time that recording files are kept on disk. Older recordings will be automatically deleted.",
          options: RecordingRetention.allCases.map { MenuOption(value: $0, label: $0.displayName) },
          selection: $store.timberVoxSettings.recordingRetention
        )

      }
    }
  }

  private var permissionsSection: some View {
    PaneSection(title: "Permissions") {
      Card {
        HStack(spacing: 12) {
          Image(systemName: "lock.shield")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(width: 20)
          ConfigurationPermissionPill(name: "Microphone", granted: microphonePermission == .granted)
          ConfigurationPermissionPill(name: "Accessibility", granted: accessibilityPermission == .granted)
          ConfigurationPermissionPill(name: "Screen Recording", granted: screenCapturePermission == .granted)
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
      }
    }
  }

  private var updatesSection: some View {
    PaneSection(title: "Updates") {
      SettingsCard {
        #if MAS_BUILD
          SettingsRow(icon: "shippingbox", title: "Version", subtitle: appVersion) {
            EmptyView()
          }
        #else
          SettingsRow(icon: "shippingbox", title: "Version", subtitle: appVersion) {
            Button("Check for Updates...", action: updates.checkForUpdates)
              .controlSize(.small)
          }
          SettingsToggleRow(
            icon: "arrow.clockwise",
            title: "Automatically check for updates",
            hint: "If enabled, \(AppBrand.name) will automatically check for updates every three hours.",
            isOn: Binding(
              get: { updates.automaticallyChecksForUpdates },
              set: { updates.automaticallyChecksForUpdates = $0 }
            )
          )
          SettingsToggleRow(
            icon: "arrow.down.circle",
            title: "Automatically download updates",
            hint: "Updates install quietly on next launch.",
            isOn: Binding(
              get: { updates.automaticallyDownloadsUpdates },
              set: { updates.automaticallyDownloadsUpdates = $0 }
            )
          )
        #endif

      }
    }
  }

  private var advancedEntryRow: some View {
    Button {
      route = .advanced
    } label: {
      HStack {
        Text("Advanced settings")
          .font(.system(size: 13, weight: .semibold))
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 16)
      .frame(height: 50)
      .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
    .buttonStyle(.plain)
  }
}

private extension ConfigurationPane {
  private var advancedApplicationSection: some View {
    PaneSection(title: "Application") {
      SettingsCard {
        SettingsToggleRow(
          icon: "dock.rectangle",
          title: "Show in Dock",
          hint:
            "If enabled, the Application will show in the Dock when running. "
            + "If disabled, the Application will only show in Dock when the settings window is open.",
          isOn: $store.timberVoxSettings.showDockIcon
        )

      }
    }
  }

  private var advancedTextInputSection: some View {
    PaneSection(title: "Text Input") {
      SettingsCard {
        SettingsToggleRow(
          icon: "doc.on.clipboard",
          title: "Paste result text",
          hint: "If enabled, the results of your dictation will be automatically pasted into the focused text input when your dictation completes.",
          isOn: $store.timberVoxSettings.autoPasteResult
        )
        ConfigurationMenuRow(
          icon: "doc.on.clipboard",
          title: "Clipboard behaviour",
          hint: "Controls how your clipboard is handled after pasting transcription text.",
          options: ClipboardRestoreBehavior.allCases.map { MenuOption(value: $0, label: $0.displayName) },
          selection: $store.timberVoxSettings.clipboardRestoreBehavior
        )
        SettingsToggleRow(
          icon: "keyboard",
          title: "Simulate keypresses",
          hint:
            "Warning this is an Experimental feature, only Standard US QWERTY layout keyboards are supported. "
            + "If enabled, instead of pasting the clipboard, the application will simulate key presses from your "
            + "keyboard and text will stream from your cursor.",
          showsAI: true,
          isOn: Binding(
            get: { !store.timberVoxSettings.useClipboardPaste },
            set: { store.timberVoxSettings.useClipboardPaste = !$0 }
          )
        )

      }
    }
  }

}

#Preview("Configuration") {
  @Previewable @State var store = AppPreviewState.makeStore()
  FloatingHost {
    ConfigurationPane(
      store: store.settings,
      microphonePermission: .granted,
      accessibilityPermission: .granted,
      screenCapturePermission: .notDetermined
    )
    .frame(width: 660, height: 760)
    .background(Theme.windowBackground)
  }
}
