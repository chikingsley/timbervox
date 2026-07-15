import KeyboardShortcuts
import SwiftUI

struct ModeDetailForm: View {
  let modeID: String
  @Bindable var modeStore: ModeStore
  @Bindable var transcriptionCatalog: TranscriptionModelCatalogStore

  @State private var showsActivationSheet = false

  private var mode: DictationMode? {
    modeStore.mode(id: modeID)
  }

  private var capabilities: ModeModelCapabilities? {
    guard let mode else { return nil }
    return ModeCatalogResolver.capabilities(for: mode, catalog: transcriptionCatalog.models)
  }

  private var bindings: ModeFormBindingSource {
    ModeFormBindingSource(
      modeID: modeID,
      modeStore: modeStore,
      transcriptionCatalog: transcriptionCatalog
    )
  }

  var body: some View {
    if let mode {
      ScrollView {
        VStack(spacing: AppSpacing.md) {
          presetPanel(mode).zIndex(3)
          if mode.textTransformPreset.allowsContextSelection {
            contextPanel(mode)
          }
          transcriptionPanel(mode).zIndex(2)
          activationPanel(mode).zIndex(1)
          advancedAudioPanel(mode)
        }
        .appContentColumn(topInset: AppSpacing.lg, bottomInset: AppSpacing.xl)
      }
      .scSheet(isPresented: $showsActivationSheet, edge: .trailing) {
        ModeActivationSheet(
          selectedBundleIdentifiers: bindings.modeBinding(
            \.activationBundleIdentifiers,
            fallback: mode.activationBundleIdentifiers
          )
        )
      }
    }
  }

  private func contextPanel(_ mode: DictationMode) -> some View {
    ModeContextCard(
      includeApplication: bindings.contextOptionBinding(
        \.includeApplicationContext,
        mode: mode
      ),
      includeSelection: bindings.contextOptionBinding(
        \.includeSelectionContext,
        mode: mode
      ),
      includeClipboard: bindings.contextOptionBinding(
        \.includeClipboardContext,
        mode: mode
      ),
      includeScreen: bindings.contextOptionBinding(
        \.includeScreenContext,
        mode: mode
      )
    )
  }

  private func presetPanel(_ mode: DictationMode) -> some View {
    ModeSettingsPanel {
      ModeSettingsRow(
        "Preset",
        hint: "Choose how TimberVox should process the transcript after speech recognition."
      ) {
        ModePresetPicker(selection: bindings.optionalPreset(mode))
          .frame(width: ModeLayout.controlWidth)
      }
      .zIndex(10)

      if mode.textTransformPreset == .custom {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
          Text("Custom instructions")
            .font(.system(size: 14, weight: .semibold))
          SCTextarea(
            "Describe how TimberVox should transform the transcript.",
            text: bindings.modeBinding(
              \.customTextTransformInstructions,
              fallback: mode.customTextTransformInstructions
            ),
            minHeight: 112
          )
        }
      }
    }
  }

  private func transcriptionPanel(_ mode: DictationMode) -> some View {
    ModeSettingsPanel {
      ModeSettingsRow("Language") {
        ModeLanguageComboboxPicker(
          selection: bindings.optionalLanguage(mode),
          options: languageOptions
        )
        .frame(width: ModeLayout.controlWidth)
      }

      ModeSettingsRow(
        "Voice Model",
        hint: "The speech recognition model used by this mode."
      ) {
        ModeVoiceModelPicker(
          selection: bindings.optionalAudioModelID(mode),
          models: transcriptionCatalog.models
        )
        .frame(width: ModeLayout.controlWidth)
      }
      .zIndex(10)

      if capabilities?.supportsRealtime ?? false,
        capabilities?.supportsBatch ?? false
      {
        ModeSettingsRow("Realtime") {
          Toggle(isOn: bindings.modeBinding(\.realtimeEnabled, fallback: mode.realtimeEnabled)) {
            EmptyView()
          }
          .toggleStyle(.scSwitch)
          .accessibilityLabel("Realtime")
        }
      }

      if mode.usesTextTransform {
        ModeSettingsRow("Language Model") {
          ModeLanguageModelPicker(
            selection: bindings.optionalLanguageModelID(mode),
            models: transcriptionCatalog.languageModels
          )
          .frame(width: ModeLayout.controlWidth)
        }
        .zIndex(9)
      }
    }
  }

  private func activationPanel(_ mode: DictationMode) -> some View {
    ModeSettingsPanel {
      ModeSettingsRow(
        "Activate for apps",
        hint: "Automatically use this mode when recording from selected applications."
      ) {
        Button(activationButtonLabel(mode)) {
          showsActivationSheet = true
        }
        .buttonStyle(.sc(.secondary, size: .sm))
      }

      ModeSettingsRow(
        "Keyboard shortcut",
        detail: "Start a recording using the active mode"
      ) {
        KeyboardShortcuts.Recorder(for: .toggleDictation)
      }
    }
  }

  private func advancedAudioPanel(_ mode: DictationMode) -> some View {
    ModeSettingsPanel {
      ModeSettingsRow(
        "Playback when recording",
        hint: "Controls other applications' audio while TimberVox records."
      ) {
        SCSelect(
          selection: bindings.optionalPlaybackPolicy(mode),
          options: PlaybackPolicy.allCases.map {
            SCSelectOption(value: $0, label: playbackLabel($0))
          }
        )
        .frame(width: ModeLayout.controlWidth)
      }

      ModeSettingsRow(
        "Record from system audio",
        hint: "Capture application audio together with the microphone."
      ) {
        Toggle(isOn: bindings.modeBinding(\.includesSystemAudio, fallback: mode.includesSystemAudio)) {
          EmptyView()
        }
        .toggleStyle(.scSwitch)
        .accessibilityLabel("Record from system audio")
      }

      if capabilities?.supportsDiarization ?? false {
        ModeSettingsRow(
          "Identify Speakers",
          hint: "Separate speakers when the selected transcription route supports it."
        ) {
          Toggle(isOn: bindings.modeBinding(\.diarizationEnabled, fallback: mode.diarizationEnabled)) {
            EmptyView()
          }
          .toggleStyle(.scSwitch)
          .accessibilityLabel("Identify Speakers")
        }
      }
    }
  }

  private var languageOptions: [SCComboboxOption<String>] {
    var options: [SCComboboxOption<String>] = []
    if capabilities?.supportsAutomaticLanguage ?? false {
      options.append(SCComboboxOption(value: "", label: "Automatic"))
    }
    options += (capabilities?.supportedLanguages ?? []).map {
      SCComboboxOption(value: $0, label: ModeLanguageLabel.name(for: $0))
    }
    return options
  }

  private func activationButtonLabel(_ mode: DictationMode) -> String {
    let count = mode.activationBundleIdentifiers.count
    return count == 0 ? "Add apps" : "\(count) selected"
  }

  private func playbackLabel(_ policy: PlaybackPolicy) -> String {
    policy == .pauseMedia ? "Pause (Default)" : policy.label
  }

}
