import Inject
import SwiftUI

struct PrototypeCommandsView: View {
  @Binding var destination: PrototypeDestination?
  @State private var commands = PrototypeVoiceCommand.samples
  @State private var selectedID = PrototypeVoiceCommand.samples.first?.id
  @State private var hotMicEnabled = false
  @ObserveInjection var injection

  private var selected: PrototypeVoiceCommand? { commands.first { $0.id == selectedID } }

  var body: some View {
    PrototypeCollectionLayout(destination: $destination) {
      commandList
    } detail: {
      Group {
        if let selected {
          PrototypeCommandForm(command: binding(for: selected.id))
        } else {
          ContentUnavailableView(
            "Select a Command", systemImage: "waveform.badge.mic",
            description: Text("Configure a voice-triggered workflow."))
        }
      }
      .toolbar { detailToolbar }
    }
    .navigationTitle(selectedCommandName)
    .enableInjection()
  }

  private var selectedCommandName: Binding<String> {
    guard let selectedID, commands.contains(where: { $0.id == selectedID }) else {
      return .constant("Commands")
    }
    return binding(for: selectedID).name
  }

  @ToolbarContentBuilder private var detailToolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Toggle("Hot Mic", systemImage: "mic.badge.plus", isOn: $hotMicEnabled)
        .toggleStyle(.button)
      Button("Duplicate", systemImage: "plus.square.on.square", action: duplicateCommand)
        .labelStyle(.iconOnly)
        .help("Duplicate command")
      Button(role: .destructive, action: deleteCommand) {
        Label("Delete", systemImage: "trash")
      }
      .labelStyle(.iconOnly)
      .help("Delete command")
      .disabled(selected == nil)
    }
  }

  private var commandList: some View {
    List(selection: $selectedID) {
      Section("Voice Commands") {
        ForEach(commands) { command in
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text(command.name)
              Text("“\(command.trigger)”")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if !command.isEnabled {
              Text("Off")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 3)
          .tag(command.id)
        }
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button("Add Command", systemImage: "plus", action: addCommand)
      }
    }
  }

  private func binding(for id: UUID) -> Binding<PrototypeVoiceCommand> {
    Binding(
      get: { commands.first { $0.id == id } ?? PrototypeVoiceCommand.samples[0] },
      set: { updated in
        guard let index = commands.firstIndex(where: { $0.id == id }) else { return }
        commands[index] = updated
      })
  }

  private func addCommand() {
    let command = PrototypeVoiceCommand(
      id: UUID(), name: "New Command", trigger: "", action: "Run a workflow",
      confirmation: "Ask first", mode: "Any mode", isEnabled: true)
    commands.append(command)
    selectedID = command.id
  }

  private func deleteCommand() {
    guard let selectedID else { return }
    commands.removeAll { $0.id == selectedID }
    self.selectedID = commands.first?.id
  }

  private func duplicateCommand() {
    guard let selected else { return }
    let copy = PrototypeVoiceCommand(
      id: UUID(), name: "\(selected.name) Copy", trigger: selected.trigger,
      action: selected.action, confirmation: selected.confirmation, mode: selected.mode,
      isEnabled: selected.isEnabled)
    commands.append(copy)
    selectedID = copy.id
  }
}

private struct PrototypeCommandForm: View {
  @Binding var command: PrototypeVoiceCommand

  var body: some View {
    Form {
      Section("Command") {
        TextField("Name", text: $command.name)
        Toggle("Enabled", isOn: $command.isEnabled)
        TextField("Trigger phrase", text: $command.trigger, prompt: Text("What should TimberVox listen for?"))
      }

      Section("Workflow") {
        Picker("Action", selection: $command.action) {
          Text("Start standalone note").tag("Start standalone note")
          Text("Open meeting setup").tag("Open meeting setup")
          Text("Run Email workflow").tag("Run Email workflow")
          Text("Run a workflow").tag("Run a workflow")
        }
        Picker("Mode", selection: $command.mode) {
          Text("Any mode").tag("Any mode")
          Text("Voice to Text").tag("Voice to Text")
          Text("Email").tag("Email")
          Text("Notes").tag("Notes")
        }
      }

      Section("Confirmation") {
        Picker("After recognition", selection: $command.confirmation) {
          Text("Ask first").tag("Ask first")
          Text("Sound").tag("Sound")
          Text("Show result").tag("Show result")
          Text("Run immediately").tag("Run immediately")
        }
        Text("Confirmation behavior should match the risk of the selected action.")
          .foregroundStyle(.secondary)
      }

      Section("Test") {
        LabeledContent {
          Button("Try Command") {}
        } label: {
          Text(command.trigger.isEmpty ? "Add a trigger phrase first" : "Say “\(command.trigger)”")
          Text("Uses the active Hot Mic profile without changing keyboard shortcuts")
        }
      }
    }
    .formStyle(.grouped)
  }
}

#Preview("Commands") {
  PrototypeCommandsView(destination: .constant(.commands))
    .frame(width: 940, height: 700)
}
