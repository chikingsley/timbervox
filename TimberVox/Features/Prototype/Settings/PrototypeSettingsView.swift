import Inject
import SwiftUI

struct PrototypeSettingsView: View {
  let openSetup: () -> Void
  @State private var selectedPane = PrototypeSettingsPane.general
  @ObserveInjection var injection

  var body: some View {
    VStack(spacing: 0) {
      Picker("Settings", selection: $selectedPane) {
        ForEach(PrototypeSettingsPane.allCases) { pane in
          Label(pane.title, systemImage: pane.systemImage)
            .tag(pane)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding()

      Divider()
      settingsForm
    }
    .navigationTitle("Settings")
    .enableInjection()
  }

  @ViewBuilder private var settingsForm: some View {
    switch selectedPane {
    case .general:
      PrototypeGeneralSettings(openSetup: openSetup)
    case .shortcuts:
      PrototypeShortcutSettings()
    case .recording:
      PrototypeRecordingSettings()
    case .models:
      PrototypeModelSettings()
    case .account:
      PrototypeAccountSettings()
    }
  }
}

private enum PrototypeSettingsPane: String, CaseIterable, Identifiable {
  case general
  case shortcuts
  case recording
  case models
  case account

  var id: String { rawValue }

  var title: String { rawValue.capitalized }

  var systemImage: String {
    switch self {
    case .general: "gear"
    case .shortcuts: "keyboard"
    case .recording: "mic"
    case .models: "cpu"
    case .account: "person.crop.circle"
    }
  }
}

private struct PrototypeGeneralSettings: View {
  let openSetup: () -> Void
  @State private var appearance = "Automatic"
  @State private var launchAtLogin = true
  @State private var showInMenuBar = true
  @State private var microphoneGranted = true
  @State private var accessibilityGranted = true

  var body: some View {
    Form {
      Section("Application") {
        Toggle("Launch TimberVox at login", isOn: $launchAtLogin)
        Toggle("Show TimberVox in the menu bar", isOn: $showInMenuBar)
        Picker("Appearance", selection: $appearance) {
          Text("Automatic").tag("Automatic")
          Text("Light").tag("Light")
          Text("Dark").tag("Dark")
        }
      }

      Section {
        LabeledContent("Microphone") {
          permissionControl(granted: $microphoneGranted)
        }
        LabeledContent("Accessibility") {
          permissionControl(granted: $accessibilityGranted)
        }
        Button("Open Setup Assistant", action: openSetup)
      } header: {
        Text("Setup")
      } footer: {
        Text("Optional access, such as system audio, is requested only when its feature is used.")
      }

      Section("History") {
        Picker("Keep audio", selection: .constant("Forever")) {
          Text("Forever").tag("Forever")
          Text("30 days").tag("30 days")
          Text("Never").tag("Never")
        }
        Button("Open History Folder") {}
      }
    }
    .formStyle(.grouped)
  }

  private func permissionControl(granted: Binding<Bool>) -> some View {
    Group {
      if granted.wrappedValue {
        Label("Granted", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
      } else {
        Button("Grant") { granted.wrappedValue = true }
      }
    }
  }
}

private struct PrototypeShortcutSettings: View {
  var body: some View {
    Form {
      Section("Dictation") {
        PrototypeShortcutRow(
          title: "Toggle dictation", description: "Start or stop recording anywhere", shortcut: "⌥ Space")
        PrototypeShortcutRow(
          title: "Cancel recording", description: "Discard the current recording", shortcut: "⌥ Escape")
        PrototypeShortcutRow(title: "Choose mode", description: "Open the compact mode switcher", shortcut: "⌥ M")
      }
      Section("Application") {
        PrototypeShortcutRow(title: "Open TimberVox", description: "Show the main window", shortcut: "⌘ ⇧ T")
        PrototypeShortcutRow(title: "Settings", description: "Open TimberVox settings", shortcut: "⌘ ,")
      }
    }
    .formStyle(.grouped)
  }
}

private struct PrototypeShortcutRow: View {
  let title: String
  let description: String
  let shortcut: String

  var body: some View {
    LabeledContent {
      Button(shortcut) {}
        .monospaced()
    } label: {
      Text(title)
      Text(description)
    }
  }
}

private struct PrototypeRecordingSettings: View {
  @State private var input = "System Default"
  @State private var feedback = true
  @State private var indicator = "Large Pill"

  var body: some View {
    Form {
      Section("Input") {
        Picker("Microphone", selection: $input) {
          Text("System Default").tag("System Default")
          Text("MacBook Pro Microphone").tag("MacBook Pro Microphone")
        }
        LabeledContent("Input level") {
          ProgressView(value: 0.62)
            .frame(width: 160)
        }
      }
      Section("Feedback") {
        Toggle("Play start and stop sounds", isOn: $feedback)
        Picker("Sound set", selection: .constant("Default")) {
          Text("Default").tag("Default")
          Text("Classic").tag("Classic")
          Text("None").tag("None")
        }
      }
      Section("Recording Indicator") {
        Picker("Style", selection: $indicator) {
          Text("Large Pill").tag("Large Pill")
          Text("Compact Pill").tag("Compact Pill")
          Text("Minimal").tag("Minimal")
        }
        Toggle("Show active mode", isOn: .constant(true))
      }
    }
    .formStyle(.grouped)
  }
}

private struct PrototypeModelSettings: View {
  var body: some View {
    Form {
      Section("Cloud Models") {
        LabeledContent("Catalog") {
          Label("Current", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
        }
        LabeledContent("Available transcription models", value: "6")
        Button("Refresh Catalog") {}
      }
      Section("Local Models") {
        LabeledContent {
          Button("Download") {}
        } label: {
          Text("Whisper Large v3 Turbo")
          Text("1.6 GB · multilingual transcription")
        }
        LabeledContent {
          Label("Installed", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
        } label: {
          Text("Parakeet TDT 0.6B")
          Text("640 MB · English transcription")
        }
      }
    }
    .formStyle(.grouped)
  }
}

private struct PrototypeAccountSettings: View {
  var body: some View {
    Form {
      Section("Cloud Access") {
        LabeledContent("Plan") {
          Label("Active", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
        }
        LabeledContent("Usage this month", value: "2 hr 14 min")
        Button("Manage Subscription") {}
        Button("Restore Purchases") {}
      }
      Section("Installation") {
        LabeledContent("Credential", value: "Valid for 21 days")
        LabeledContent("Installation ID", value: "TVX-7A92")
        Button("Refresh Credential") {}
      }
      Section("About") {
        LabeledContent("TimberVox", value: "1.0 (79)")
        Button("Check for Updates") {}
      }
    }
    .formStyle(.grouped)
  }
}

#Preview("Settings") {
  PrototypeSettingsView {}
    .frame(width: 900, height: 700)
}
