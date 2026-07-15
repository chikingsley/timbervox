import KeyboardShortcuts
import ServiceManagement
import SwiftUI

enum AppearanceChoice: String, CaseIterable, Identifiable {
  case automatic, light, dark

  var id: String { rawValue }

  var label: String {
    switch self {
    case .automatic: "Auto"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .automatic: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

struct SettingsPane: View {
  let dictation: DictationController
  let billing: SubscriptionController
  let permissions: PermissionCoordinator
  @AppStorage("appearance") private var appearanceRaw = AppearanceChoice.automatic.rawValue
  @AppStorage("indicatorStyle") private var indicatorStyleRaw = IndicatorStyle.defaultValue.rawValue
  @AppStorage(ClipboardRetentionPreference.keepTranscriptOnClipboardAfterPasteKey)
  private var keepTranscriptOnClipboardAfterPaste = ClipboardRetentionPreference
    .defaultKeepTranscriptOnClipboardAfterPaste
  @AppStorage(FluidAudioModelRetentionPreference.key)
  private var localModelRetentionMinutes = FluidAudioModelRetentionPreference.defaultMinutes
  @AppStorage(DictationContextRetentionPreference.key)
  private var contextRetentionDays = DictationContextRetentionPreference.defaultDays

  @State private var launchAtLogin = false
  @State private var launchAtLoginLoaded = false
  @Environment(\.theme) private var theme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppSpacing.lg) {
        appearanceCard
        indicatorCard
        shortcutsCard
        clipboardCard
        localModelsCard
        historyCard
        applicationCard
        SettingsPlansCard(billing: billing)
        SettingsAccessGrid(permissions: permissions)
      }
      .appContentColumn(topInset: AppSpacing.lg, bottomInset: AppSpacing.xl)
    }
    .scrollIndicators(.hidden)
    .foregroundStyle(theme.foreground)
    .background(theme.background)
    .onAppear {
      permissions.refresh()
    }
    .task {
      // Checking launchd status is a blocking call out of process; keep it off the main thread.
      launchAtLogin = await Task.detached { SMAppService.mainApp.status == .enabled }.value
      launchAtLoginLoaded = true
    }
    .onChange(of: launchAtLogin) { _, enabled in
      guard launchAtLoginLoaded else { return }
      do {
        if enabled {
          try SMAppService.mainApp.register()
        } else {
          try SMAppService.mainApp.unregister()
        }
      } catch {
        launchAtLogin = SMAppService.mainApp.status == .enabled
      }
    }
    .onChange(of: localModelRetentionMinutes) { _, _ in
      Task {
        await FluidAudioBatchTranscriber.shared.retentionPreferenceDidChange()
        await FluidAudioRealtimeTranscriptionSession.shared.retentionPreferenceDidChange()
      }
    }
    .onChange(of: contextRetentionDays) { _, _ in
      Task.detached(priority: .background) {
        DictationContextRetentionSweeper.sweep()
      }
    }
  }

  private var appearanceCard: some View {
    AppSettingsCard("Appearance") {
      AppSettingsRow("Theme") {
        SCToggleGroup(
          selection: appearanceBinding,
          items: AppearanceChoice.allCases.map {
            SCToggleGroupItem(value: $0, label: $0.label)
          }
        )
      }
    }
  }

  private var indicatorCard: some View {
    AppSettingsCard(
      "Recording indicator",
      description: "How TimberVox shows recording and processing on screen."
    ) {
      SettingsIndicatorPreview(styleRaw: $indicatorStyleRaw)
    }
  }

  private var shortcutsCard: some View {
    AppSettingsCard("Keyboard shortcuts", description: "Cancel is only active while recording.") {
      AppSettingsRow("Toggle dictation", detail: "Starts and stops recording anywhere") {
        KeyboardShortcuts.Recorder(for: .toggleDictation)
      }

      SCSeparator()

      AppSettingsRow("Cancel recording", detail: "Discards the recording in progress") {
        KeyboardShortcuts.Recorder(for: .cancelRecording)
      }
    }
  }

  private var clipboardCard: some View {
    AppSettingsCard("Clipboard") {
      AppSettingsRow(
        "Keep transcript on clipboard",
        detail: keepTranscriptOnClipboardAfterPaste
          ? "After auto-paste, the transcript stays on your clipboard."
          : "After auto-paste, TimberVox restores your previous clipboard."
      ) {
        SCSwitch("Keep transcript on clipboard", isOn: $keepTranscriptOnClipboardAfterPaste)
      }
    }
  }

  private var localModelsCard: some View {
    AppSettingsCard(
      "Local models",
      description:
        "TimberVox keeps only the most recently requested local batch or realtime model in memory."
    ) {
      AppSettingsRow("Unload last-used model after") {
        SCSelect(
          selection: retentionBinding($localModelRetentionMinutes),
          options: FluidAudioModelRetentionOption.allCases.map {
            SCSelectOption(value: $0.rawValue, label: $0.label)
          }
        )
        .frame(width: 160)
      }
    }
  }

  private var historyCard: some View {
    AppSettingsCard(
      "History",
      description:
        "Screenshots and clipboard images captured for AI processing are deleted after this period. Transcripts are never deleted automatically."
    ) {
      AppSettingsRow("Keep captured context") {
        SCSelect(
          selection: retentionBinding($contextRetentionDays),
          options: DictationContextRetentionOption.allCases.map {
            SCSelectOption(value: $0.rawValue, label: $0.label)
          }
        )
        .frame(width: 160)
      }
    }
  }

  private var applicationCard: some View {
    AppSettingsCard("Application") {
      AppSettingsRow("Launch at login") {
        SCSwitch("Launch at login", isOn: $launchAtLogin, isDisabled: !launchAtLoginLoaded)
      }
    }
  }

  private var appearanceBinding: Binding<AppearanceChoice?> {
    Binding(
      get: { AppearanceChoice(rawValue: appearanceRaw) ?? .automatic },
      set: { choice in
        if let choice { appearanceRaw = choice.rawValue }
      }
    )
  }

  private func retentionBinding(_ storage: Binding<Int>) -> Binding<Int?> {
    Binding(
      get: { storage.wrappedValue },
      set: { value in
        if let value { storage.wrappedValue = value }
      }
    )
  }
}
