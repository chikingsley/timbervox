import SwiftUI

struct ModeDetailForm: View {
  let modeID: String
  @Bindable var modeStore: ModeStore
  @Bindable var transcriptionCatalog: TranscriptionModelCatalogStore
  let onDuplicate: () -> Void
  let onDelete: () -> Void

  private var mode: DictationMode? {
    modeStore.mode(id: modeID)
  }

  private var capabilities: ModeModelCapabilities? {
    guard let mode else { return nil }
    return ModeCatalogResolver.capabilities(for: mode, catalog: transcriptionCatalog.models)
  }

  var body: some View {
    if let mode {
      Form {
        identitySection(mode)
        transcriptionSection(mode)
        textTransformSection(mode)
      }
      .formStyle(.grouped)
      .navigationTitle(mode.name)
      .toolbar {
        ToolbarItem(placement: .principal) {
          TextField("Mode name", text: nameBinding(mode))
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.headline)
            .frame(minWidth: 140, idealWidth: 220, maxWidth: 300)
            .accessibilityLabel("Mode name")
        }
        ToolbarItemGroup(placement: .primaryAction) {
          Button("Duplicate Mode", systemImage: "plus.square.on.square", action: onDuplicate)
            .labelStyle(.iconOnly)
            .help("Duplicate mode")
          Button("Delete Mode", systemImage: "trash", role: .destructive, action: onDelete)
            .labelStyle(.iconOnly)
            .help("Delete mode")
            .disabled(modeStore.modes.count <= 1)
        }
      }
    }
  }

  private func identitySection(_ mode: DictationMode) -> some View {
    Section("Mode") {
      Picker("Icon", selection: iconBinding(mode)) {
        Label("Automatic", systemImage: mode.textTransformPreset.systemImage)
          .tag(ModeLanguageLabel.automaticID)
        ForEach(Self.iconChoices, id: \.self) { icon in
          Label(ModeIconLabel.name(for: icon), systemImage: icon)
            .tag(icon)
        }
      }

      if mode.id == modeStore.activeModeID {
        LabeledContent("Status") {
          Label("Active", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
        }
      } else {
        Button("Use Mode", systemImage: "play.circle") {
          modeStore.activeModeID = mode.id
        }
      }
    }
  }

  private func transcriptionSection(_ mode: DictationMode) -> some View {
    Section("Transcription") {
      Picker("Audio model", selection: modeBinding(\.audioModelID, fallback: mode.audioModelID)) {
        if !transcriptionCatalog.models.contains(where: { $0.id == mode.audioModelID }) {
          Text(modelLabel(mode.audioModelID)).tag(mode.audioModelID)
        }
        ForEach(transcriptionCatalog.models) { model in
          Text(model.menuLabel).tag(model.id)
        }
      }

      if let model = transcriptionCatalog.model(id: mode.audioModelID) {
        TranscriptionModelExperienceView(model: model)
      }

      ModeLanguagePicker(
        selection: languageBinding(mode),
        supportedLanguages: capabilities?.supportedLanguages ?? [],
        supportsAutomaticLanguage: capabilities?.supportsAutomaticLanguage ?? false
      )

      if let capabilities {
        if capabilities.supportsBatch, capabilities.supportsRealtime {
          Toggle("Realtime streaming", isOn: modeBinding(\.realtimeEnabled, fallback: mode.realtimeEnabled))
        }

        if capabilities.supportsDiarization {
          Toggle("Diarization", isOn: modeBinding(\.diarizationEnabled, fallback: mode.diarizationEnabled))
        }
      }

      Toggle(
        "Include system audio",
        isOn: modeBinding(\.includesSystemAudio, fallback: mode.includesSystemAudio)
      )
      Text("Records the microphone and Mac audio together.")
        .font(.caption)
        .foregroundStyle(.secondary)

      Picker(
        "While recording",
        selection: modeBinding(\.playbackPolicy, fallback: mode.playbackPolicy)
      ) {
        ForEach(PlaybackPolicy.allCases) { policy in
          Text(policy.label).tag(policy)
        }
      }
      if mode.playbackPolicy == .pauseMedia {
        Text(
          "Pauses Music, Spotify, and VLC, plus whatever the play/pause key controls, like a video in your browser."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      if mode.includesSystemAudio, mode.playbackPolicy == .pauseMedia {
        Text("Pause media stops the Mac audio this mode would capture.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func textTransformSection(_ mode: DictationMode) -> some View {
    Section("Text transform") {
      Picker("Preset", selection: presetBinding(mode)) {
        ForEach(ModeTextTransformPreset.allCases) { preset in
          Label(preset.label, systemImage: preset.systemImage).tag(preset)
        }
      }
      Text(mode.textTransformPreset.explanation)
        .font(.caption)
        .foregroundStyle(.secondary)

      if mode.usesTextTransform {
        Picker(
          "Language model",
          selection: modeBinding(\.textTransformModelID, fallback: mode.textTransformModelID)
        ) {
          if !transcriptionCatalog.languageModels.contains(where: { $0.id == mode.textTransformModelID }) {
            Text(modelLabel(mode.textTransformModelID)).tag(mode.textTransformModelID)
          }
          ForEach(transcriptionCatalog.languageModels) { model in
            Text(model.menuLabel).tag(model.id)
          }
        }

        if mode.textTransformPreset == .custom {
          VStack(alignment: .leading, spacing: 8) {
            Text("Prompt")
              .font(.headline)
            TextEditor(
              text: modeBinding(
                \.customTextTransformInstructions,
                fallback: mode.customTextTransformInstructions
              )
            )
            .frame(minHeight: 110)
            .accessibilityLabel("Custom prompt")
          }

          ModeContextPicker(
            includeApplication: contextBinding(\.includeApplicationContext, mode: mode),
            includeSelection: contextBinding(\.includeSelectionContext, mode: mode),
            includeClipboard: contextBinding(\.includeClipboardContext, mode: mode),
            includeScreen: contextBinding(\.includeScreenContext, mode: mode)
          )
        } else {
          Label("Uses all available context automatically", systemImage: "checkmark.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func nameBinding(_ mode: DictationMode) -> Binding<String> {
    Binding {
      modeStore.mode(id: modeID)?.name ?? mode.name
    } set: { value in
      updateMode {
        $0.name = value
        $0.nameIsCustomized = true
      }
    }
  }

  private func iconBinding(_ mode: DictationMode) -> Binding<String> {
    Binding {
      modeStore.mode(id: modeID)?.iconSystemName ?? ModeLanguageLabel.automaticID
    } set: { value in
      updateMode {
        $0.iconSystemName = value == ModeLanguageLabel.automaticID ? nil : value
      }
    }
  }

  private func presetBinding(_ mode: DictationMode) -> Binding<ModeTextTransformPreset> {
    Binding {
      modeStore.mode(id: modeID)?.textTransformPreset ?? mode.textTransformPreset
    } set: { preset in
      updateMode {
        let previousPreset = $0.textTransformPreset
        $0.textTransformPreset = preset
        if preset.allowsContextSelection, previousPreset != .custom {
          $0.textTransformContextOptions = .none
        } else if preset.usesAllAvailableContext {
          $0.textTransformContextOptions = .allAvailable
        }
        if preset == .custom,
          $0.customTextTransformInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
          $0.customTextTransformInstructions = TextTransformPreset.defaultCustomInstructions
        }
        if !$0.nameIsCustomized {
          $0.name = preset.label
        }
      }
    }
  }

  private func languageBinding(_ mode: DictationMode) -> Binding<String> {
    Binding {
      modeStore.mode(id: modeID)?.languageCode ?? ModeLanguageLabel.automaticID
    } set: { value in
      updateMode {
        $0.languageCode = value == ModeLanguageLabel.automaticID ? nil : value
      }
    }
  }

  private func modeBinding<Value: Equatable>(
    _ keyPath: WritableKeyPath<DictationMode, Value>,
    fallback: Value
  ) -> Binding<Value> {
    Binding {
      modeStore.mode(id: modeID)?[keyPath: keyPath] ?? fallback
    } set: { value in
      updateMode { $0[keyPath: keyPath] = value }
    }
  }

  private func contextBinding(
    _ keyPath: WritableKeyPath<DictationContextOptions, Bool>,
    mode: DictationMode
  ) -> Binding<Bool> {
    Binding {
      modeStore.mode(id: modeID)?.textTransformContextOptions[keyPath: keyPath]
        ?? mode.textTransformContextOptions[keyPath: keyPath]
    } set: { value in
      updateMode { $0.textTransformContextOptions[keyPath: keyPath] = value }
    }
  }

  private func updateMode(_ update: (inout DictationMode) -> Void) {
    modeStore.updateMode(id: modeID, update)
    guard let current = modeStore.mode(id: modeID) else { return }
    let normalized = transcriptionCatalog.normalized(current)
    guard normalized != current else { return }
    modeStore.updateMode(id: modeID) { $0 = normalized }
  }

  private func modelLabel(_ modelID: String) -> String {
    transcriptionCatalog.model(id: modelID)?.menuLabel
      ?? transcriptionCatalog.languageModels.first { $0.id == modelID }?.menuLabel
      ?? modelID
      .replacingOccurrences(of: "/", with: " / ")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .capitalized
  }

  private static let iconChoices = [
    "mic.fill",
    "sparkles",
    "bubble.left.fill",
    "note.text",
    "envelope.fill",
    "person.2.fill",
    "text.badge.checkmark",
    "quote.bubble.fill",
    "doc.text.fill",
    "command",
    "terminal.fill",
    "bolt.fill",
  ]
}

private enum ModeIconLabel {
  static func name(for systemName: String) -> String {
    systemName
      .replacingOccurrences(of: ".fill", with: "")
      .replacingOccurrences(of: ".", with: " ")
      .capitalized
  }
}
