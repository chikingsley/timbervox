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

  @State private var launchAtLogin = false
  @State private var launchAtLoginLoaded = false

  var body: some View {
    Form {
      Section("Appearance") {
        Picker("Theme", selection: $appearanceRaw) {
          ForEach(AppearanceChoice.allCases) { choice in
            Text(choice.label).tag(choice.rawValue)
          }
        }
        .pickerStyle(.segmented)
      }

      Section {
        LabeledContent {
          KeyboardShortcuts.Recorder(for: .toggleDictation)
        } label: {
          Text("Toggle dictation")
          Text("Starts and stops recording anywhere")
        }
        LabeledContent {
          KeyboardShortcuts.Recorder(for: .cancelRecording)
        } label: {
          Text("Cancel recording")
          Text("Discards the recording in progress")
        }
      } header: {
        Text("Keyboard shortcuts")
      } footer: {
        Text("Cancel is only active while recording.")
      }

      Section {
        Toggle("Keep transcript on clipboard", isOn: $keepTranscriptOnClipboardAfterPaste)
      } header: {
        Text("Clipboard")
      } footer: {
        Text(
          keepTranscriptOnClipboardAfterPaste
            ? "After auto-paste, the transcript stays on your clipboard."
            : "After auto-paste, TimberVox restores your previous clipboard."
        )
      }

      Section("Recording indicator") {
        Picker("Style", selection: $indicatorStyleRaw) {
          ForEach(IndicatorStyle.allCases) { style in
            Text(style.label).tag(style.rawValue)
          }
        }
        .pickerStyle(.segmented)
      }

      Section {
        Picker("Unload last-used model after", selection: $localModelRetentionMinutes) {
          ForEach(FluidAudioModelRetentionOption.allCases) { option in
            Text(option.label).tag(option.rawValue)
          }
        }
      } header: {
        Text("Local models")
      } footer: {
        Text(
          "TimberVox keeps only the most recently requested local batch or realtime model in memory."
        )
      }

      Section("Application") {
        Toggle("Launch at login", isOn: $launchAtLogin)
          .disabled(!launchAtLoginLoaded)
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
      }

      Section {
        LabeledContent {
          if billing.cloudAccessIsActive {
            Label("Active", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else {
            Button("Subscribe") {
              Task { await billing.purchaseCloudAccess() }
            }
            .disabled(!billing.isConfigured || billing.isLoading)
          }
        } label: {
          Text("Cloud Access")
          Text(billing.cloudPrice)
        }

        LabeledContent {
          if billing.localProIsActive {
            Label("Active", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else {
            Text("Coming soon")
              .foregroundStyle(.secondary)
          }
        } label: {
          Text("Local Pro")
          Text(billing.localProPrice)
        }

        Button("Restore Purchases") {
          Task { await billing.restorePurchases() }
        }
        .disabled(!billing.isConfigured || billing.isLoading)

        if let error = billing.lastError {
          Text(error)
            .foregroundStyle(.red)
        }
      } header: {
        Text("Plans")
      } footer: {
        Text(
          "Cloud Access enables hosted transcription and text processing. Local Pro will unlock offline features when they ship."
        )
      }

      Section {
        LabeledContent("Microphone") {
          if permissions.microphoneStatus.isGranted {
            Label("Granted", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else {
            Button("Grant") {
              Task { await permissions.grantMicrophone() }
            }
            .disabled(permissions.isRequestingMicrophone)
          }
        }
        LabeledContent("Accessibility") {
          if permissions.accessibilityStatus.isGranted {
            Label("Granted", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else {
            Button("Grant") {
              permissions.grantAccessibility()
            }
          }
        }
        LabeledContent("Screen capture") {
          if permissions.screenCaptureStatus.isGranted {
            Label("Granted", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else {
            Button("Grant") {
              permissions.grantScreenCapture()
            }
          }
        }
        LabeledContent("System audio") {
          if permissions.systemAudioStatus.isGranted {
            Label("Confirmed", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else {
            Button("Open Settings") {
              permissions.manageSystemAudioPermission()
            }
          }
        }
      } header: {
        Text("Permissions")
      } footer: {
        Text(
          "Screen capture and system audio are optional and independent. System audio shows Confirmed after a successful capture because macOS does not provide a preflight status API for Core Audio taps."
        )
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Settings")
    .onAppear {
      permissions.refresh()
    }
    .task {
      // Checking launchd status is a blocking call out of process; keep it off the main thread.
      launchAtLogin = await Task.detached { SMAppService.mainApp.status == .enabled }.value
      launchAtLoginLoaded = true
    }
    .onChange(of: localModelRetentionMinutes) { _, _ in
      Task {
        await FluidAudioBatchTranscriber.shared.retentionPreferenceDidChange()
        await FluidAudioRealtimeTranscriptionSession.shared.retentionPreferenceDidChange()
      }
    }
  }
}
