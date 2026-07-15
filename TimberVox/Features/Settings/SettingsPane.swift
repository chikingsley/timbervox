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
  @AppStorage(RecordingRetentionPreference.key)
  private var recordingRetentionDays = RecordingRetentionPreference.defaultDays

  @State private var launchAtLogin = false
  @State private var launchAtLoginLoaded = false
  @State private var showsClearRecordingsConfirmation = false
  @State private var storageUsedBytes: Int64 = 0
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
    .task {
      await refreshStorageUsed()
    }
    .scAlertDialog(
      isPresented: $showsClearRecordingsConfirmation,
      title: "Clear recordings?",
      message:
        "All saved dictation audio is deleted. Transcripts stay in History, but playback and re-transcribe stop working for them.",
      confirmLabel: "Clear",
      role: .destructive,
      onConfirm: clearRecordings
    )
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
      Task {
        _ = await Task.detached(priority: .background) {
          DictationContextRetentionSweeper.sweep()
        }.value
        await refreshStorageUsed()
      }
    }
    .onChange(of: recordingRetentionDays) { _, _ in
      Task {
        _ = await Task.detached(priority: .background) {
          RecordingRetentionSweeper.sweep()
        }.value
        await refreshStorageUsed()
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
      description: "Transcripts are never deleted automatically."
    ) {
      AppSettingsRow(
        "Keep captured context",
        detail: "Screenshots and clipboard images captured for AI processing."
      ) {
        SCSelect(
          selection: retentionBinding($contextRetentionDays),
          options: RetentionPeriodOption.allCases.map {
            SCSelectOption(value: $0.rawValue, label: $0.label)
          }
        )
        .frame(width: 160)
      }

      SCSeparator()

      AppSettingsRow(
        "Keep audio recordings",
        detail: "Deleting audio removes playback and re-transcribe for older dictations."
      ) {
        SCSelect(
          selection: retentionBinding($recordingRetentionDays),
          options: RetentionPeriodOption.allCases.map {
            SCSelectOption(value: $0.rawValue, label: $0.label)
          }
        )
        .frame(width: 160)
      }

      SCSeparator()

      AppSettingsInfoRow(label: "Storage used", value: storageUsedLabel)

      Button("Clear recordings", systemImage: "trash") {
        showsClearRecordingsConfirmation = true
      }
      .buttonStyle(.sc(.destructive, size: .sm))
      .disabled(dictation.state != .idle)
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

  private var storageUsedLabel: String {
    ByteCountFormatter.string(fromByteCount: storageUsedBytes, countStyle: .file)
  }

  private func refreshStorageUsed() async {
    storageUsedBytes = await Task.detached(priority: .utility) {
      AgedFileSweeper.directorySizeBytes(RecordingRetentionSweeper.recordingsDirectory())
        + AgedFileSweeper.directorySizeBytes(
          DictationContextRetentionSweeper.attachmentsDirectory()
        )
    }.value
  }

  private func clearRecordings() {
    guard dictation.state == .idle else { return }
    Task {
      await Task.detached(priority: .userInitiated) {
        guard let directory = RecordingRetentionSweeper.recordingsDirectory() else { return }
        let files =
          (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
          )) ?? []
        for file in files {
          try? FileManager.default.removeItem(at: file)
        }
      }.value
      await refreshStorageUsed()
    }
  }
}
