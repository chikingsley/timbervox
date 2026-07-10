import Inject
import SwiftUI

struct PrototypeModesView: View {
  @Binding var destination: PrototypeDestination?
  @State private var modes = PrototypeMode.samples
  @State private var selectedID = PrototypeMode.samples.first?.id
  @ObserveInjection var injection

  var body: some View {
    PrototypeCollectionLayout(destination: $destination) {
      modeList
    } detail: {
      Group {
        if let selectedID, modes.contains(where: { $0.id == selectedID }) {
          PrototypeModeForm(
            mode: binding(for: selectedID),
            canDelete: modes.count > 1,
            useMode: { makeActive(selectedID) },
            duplicate: { duplicate(selectedID) },
            delete: { delete(selectedID) })
        } else {
          ContentUnavailableView("Select a Mode", systemImage: "slider.horizontal.3")
        }
      }
    }
    .enableInjection()
  }

  private var modeList: some View {
    List(selection: $selectedID) {
      ForEach(modes) { mode in
        PrototypeModeRow(mode: mode)
          .tag(mode.id)
          .contextMenu {
            Button("Use Mode") { makeActive(mode.id) }
            Button("Duplicate") { duplicate(mode.id) }
            Divider()
            Button("Delete", role: .destructive) { delete(mode.id) }
              .disabled(modes.count < 2)
          }
      }
    }
    .navigationTitle("Modes")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button(action: addMode) {
          Label("New Mode", systemImage: "plus")
            .labelStyle(.titleAndIcon)
        }
      }
    }
  }

  private func binding(for id: UUID) -> Binding<PrototypeMode> {
    Binding(
      get: { modes.first { $0.id == id } ?? PrototypeMode.samples[0] },
      set: { updated in
        guard let index = modes.firstIndex(where: { $0.id == id }) else { return }
        modes[index] = updated
      })
  }

  private func addMode() {
    let mode = PrototypeMode(
      id: UUID(), name: "New Mode", icon: "slider.horizontal.3", transcriptionModel: "Nova 3",
      language: "Automatic", transform: "None", customPrompt: "",
      contextSources: ["Application", "Selected text"],
      activationApps: [], includesSystemAudio: false, isActive: false)
    modes.append(mode)
    selectedID = mode.id
  }

  private func duplicate(_ id: UUID) {
    guard var copy = modes.first(where: { $0.id == id }) else { return }
    copy = PrototypeMode(
      id: UUID(), name: "\(copy.name) Copy", icon: copy.icon,
      transcriptionModel: copy.transcriptionModel, language: copy.language, transform: copy.transform,
      customPrompt: copy.customPrompt, contextSources: copy.contextSources,
      activationApps: copy.activationApps,
      includesSystemAudio: copy.includesSystemAudio, isActive: false)
    modes.append(copy)
    selectedID = copy.id
  }

  private func delete(_ id: UUID) {
    guard modes.count > 1 else { return }
    modes.removeAll { $0.id == id }
    selectedID = modes.first?.id
  }

  private func makeActive(_ id: UUID) {
    for index in modes.indices {
      modes[index].isActive = modes[index].id == id
    }
  }
}

private struct PrototypeModeRow: View {
  let mode: PrototypeMode

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: mode.icon)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(mode.name)
        if mode.activationApps.isEmpty {
          Text(mode.transform)
            .foregroundStyle(.secondary)
        } else {
          Text(mode.activationApps.joined(separator: ", "))
            .foregroundStyle(.secondary)
        }
      }
      .lineLimit(1)
      Spacer()
      if mode.isActive {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .help("Active fallback mode")
      }
    }
    .padding(.vertical, 3)
  }
}

private struct PrototypeModeForm: View {
  @Binding var mode: PrototypeMode
  let canDelete: Bool
  let useMode: () -> Void
  let duplicate: () -> Void
  let delete: () -> Void

  private let contextSources = [
    "Application", "Selected text", "Focused text", "Clipboard", "Screen text",
  ]

  var body: some View {
    Form {
      Section("Transcription") {
        Picker("Model", selection: $mode.transcriptionModel) {
          Text("Nova 3").tag("Nova 3")
          Text("Scribe v2").tag("Scribe v2")
          Text("Whisper Large v3").tag("Whisper Large v3")
        }
        Picker("Language", selection: $mode.language) {
          Text("Automatic").tag("Automatic")
          Text("English").tag("English")
          Text("Spanish").tag("Spanish")
          Text("French").tag("French")
        }
        Toggle("Include system audio", isOn: $mode.includesSystemAudio)
      }

      Section("Text Transform") {
        Picker("Preset", selection: $mode.transform) {
          ForEach(["None", "Message", "Note", "Email", "Custom"], id: \.self) { value in
            Text(value).tag(value)
          }
        }
        if mode.transform == "Custom" {
          TextEditor(text: $mode.customPrompt)
            .frame(minHeight: 110)
        }
        Text("Transforms run after transcription and preserve the raw text in History.")
          .foregroundStyle(.secondary)
      }

      Section("Context") {
        ForEach(contextSources, id: \.self) { source in
          Toggle(source, isOn: contextBinding(for: source))
        }
      }

      Section("Automatic App Selection") {
        if mode.activationApps.isEmpty {
          Text("No applications automatically select this mode.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(mode.activationApps, id: \.self) { application in
            Label(application, systemImage: "app")
          }
        }
        Button("Choose Applications…") { mode.activationApps = ["Mail"] }
      }
    }
    .formStyle(.grouped)
    .toolbar {
      ToolbarItem(placement: .principal) {
        PrototypeModePrincipalHeader(
          name: $mode.name,
          isActive: mode.isActive,
          useMode: useMode)
      }
      ToolbarSpacer(.flexible)
      ToolbarItemGroup(placement: .primaryAction) {
        Button("Duplicate", systemImage: "plus.square.on.square", action: duplicate)
          .labelStyle(.iconOnly)
          .help("Duplicate mode")
        Button(role: .destructive, action: delete) {
          Label("Delete", systemImage: "trash")
        }
        .labelStyle(.iconOnly)
        .help("Delete mode")
        .disabled(!canDelete)
      }
    }
  }

  private func contextBinding(for source: String) -> Binding<Bool> {
    Binding(
      get: { mode.contextSources.contains(source) },
      set: { isIncluded in
        if isIncluded {
          mode.contextSources.insert(source)
        } else {
          mode.contextSources.remove(source)
        }
      })
  }
}

private struct PrototypeModePrincipalHeader: View {
  @Binding var name: String
  let isActive: Bool
  let useMode: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      if isActive {
        Text("Active")
          .fontWeight(.medium)
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 5)
          .background(.green, in: Capsule())
          .help("This is the active dictation mode")
      } else {
        Button("Use Mode", action: useMode)
          .buttonStyle(.plain)
          .fontWeight(.medium)
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 5)
          .background(Color.accentColor, in: Capsule())
          .help("Make this the active dictation mode")
      }

      PrototypeModeNameEditor(name: $name)
    }
    .padding(.leading, 2)
    .padding(.trailing, 10)
    .fixedSize(horizontal: true, vertical: false)
  }
}

private struct PrototypeModeNameEditor: View {
  @Binding var name: String
  @State private var draft = ""
  @State private var isEditing = false

  var body: some View {
    Group {
      if isEditing {
        HStack(spacing: 6) {
          TextField("Mode name", text: $draft)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .frame(width: editorWidth)
            .onSubmit(commit)
          Button("Rename", systemImage: "checkmark.circle.fill", action: commit)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(.green)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          Button("Cancel", systemImage: "xmark.circle.fill", action: cancel)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
      } else {
        Text(name)
          .contentShape(Rectangle())
          .onTapGesture {
            draft = name
            isEditing = true
          }
          .fontWeight(.semibold)
          .help("Rename mode")
          .accessibilityAddTraits(.isButton)
      }
    }
  }

  private var editorWidth: CGFloat {
    min(max(CGFloat(draft.count) * 8 + 28, 140), 280)
  }

  private func cancel() {
    draft = name
    isEditing = false
  }

  private func commit() {
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    name = trimmed
    isEditing = false
  }
}

#Preview("Modes - Visible Collection") {
  PrototypeModesView(destination: .constant(.modes))
    .frame(width: 940, height: 720)
}
