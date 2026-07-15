import SwiftUI

struct ModeTranscriptionCard: View {
  let mode: DictationMode
  let models: [TranscriptionModelSpec]
  let capabilities: ModeModelCapabilities?
  @Binding var audioModelID: String
  @Binding var languageCode: String?
  @Binding var realtimeEnabled: Bool
  @Binding var diarizationEnabled: Bool
  @Binding var includesSystemAudio: Bool
  @Binding var playbackPolicy: PlaybackPolicy

  private var selectedModel: TranscriptionModelSpec? {
    models.first { $0.id == audioModelID }
  }

  var body: some View {
    SCCard(size: .sm) {
      SCCardHeader {
        SCCardTitle("Transcription")
        SCCardDescription("Choose the speech model and recording behavior for this mode.")
      }

      SCCardContent {
        SCFieldGroup(spacing: AppSpacing.lg) {
          modelField
          languageField
          transportFields
          SCFieldSeparator()
          audioFields
        }
      }
    }
  }

  private var modelField: some View {
    SCField {
      SCFieldLabel("Audio model")
      SCCombobox(
        selection: optionalAudioModelID,
        options: modelOptions,
        placeholder: "Choose a model",
        searchPlaceholder: "Search models",
        trigger: { selected, expanded in
          let model = selected.first.flatMap { option in models.first { $0.id == option.value } }
          ModeComboboxTrigger(
            title: model?.displayName ?? "Choose a model",
            isExpanded: expanded,
            leading: {
              Image(systemName: model?.runtime == .local ? "desktopcomputer" : "cloud")
                .foregroundStyle(.secondary)
            },
            trailing: {
              if let model {
                SCBadge(model.runtime.label, variant: .outline)
              }
            }
          )
        },
        row: { option, selected, _ in
          modelRow(option: option, selected: selected)
        },
        groupHeader: { Text($0) },
        empty: { Text("No models found.") }
      )

      if let selectedModel {
        HStack(spacing: AppSpacing.sm) {
          SCBadge(selectedModel.runtime.label, variant: .secondary)
          if selectedModel.supportsBatch {
            SCBadge("Batch", variant: .outline)
          }
          if selectedModel.supportsRealtime {
            SCBadge("Realtime", variant: .outline)
          }
        }
        SCFieldDescription(selectedModel.presentation.summary)
      }
    }
  }

  private var languageField: some View {
    SCField {
      SCFieldLabel("Language")
      SCCombobox(
        selection: comboboxLanguageCode,
        options: languageOptions,
        placeholder: "Choose a language",
        searchPlaceholder: "Search languages"
      )
      if !(capabilities?.supportsAutomaticLanguage ?? false) {
        SCFieldDescription("This model requires a specific language.")
      }
    }
  }

  @ViewBuilder private var transportFields: some View {
    if let capabilities {
      if capabilities.supportsBatch, capabilities.supportsRealtime {
        ModeSwitchField(
          title: "Realtime streaming",
          description: "Show words while you speak, then save the final transcript.",
          isOn: $realtimeEnabled
        )
      }

      if capabilities.supportsDiarization {
        ModeSwitchField(
          title: "Diarization",
          description: "Separate speakers when the selected route supports it.",
          isOn: $diarizationEnabled
        )
      }
    }
  }

  private var audioFields: some View {
    SCFieldGroup(spacing: AppSpacing.lg) {
      ModeSwitchField(
        title: "Include system audio",
        description: "Record the microphone and Mac audio together.",
        isOn: $includesSystemAudio
      )

      SCField {
        SCFieldLabel("While recording")
        SCSelect(
          selection: optionalPlaybackPolicy,
          options: PlaybackPolicy.allCases.map {
            SCSelectOption(value: $0, label: $0.label)
          }
        )
        if playbackPolicy == .pauseMedia {
          SCFieldDescription(
            includesSystemAudio
              ? "Pausing media also stops the Mac audio this mode would capture."
              : "Pauses supported media players while recording."
          )
        }
      }
    }
  }

  private var modelOptions: [SCComboboxOption<String>] {
    models.map {
      SCComboboxOption(
        value: $0.id,
        label: $0.displayName,
        keywords: [$0.provider, $0.runtime.label, $0.technicalName ?? ""],
        group: $0.runtime.label
      )
    }
  }

  private var languageOptions: [SCComboboxOption<String>] {
    var options: [SCComboboxOption<String>] = []
    if capabilities?.supportsAutomaticLanguage ?? false {
      options.append(SCComboboxOption(value: "", label: "Automatic"))
    }
    options += (capabilities?.supportedLanguages ?? []).map {
      SCComboboxOption(value: $0, label: ModeLanguageLabel.name(for: $0), keywords: [$0])
    }
    return options
  }

  private var optionalAudioModelID: Binding<String?> {
    Binding(
      get: { audioModelID },
      set: { if let value = $0 { audioModelID = value } }
    )
  }

  private var comboboxLanguageCode: Binding<String?> {
    Binding(
      get: { languageCode ?? "" },
      set: { languageCode = ($0?.isEmpty ?? true) ? nil : $0 }
    )
  }

  private var optionalPlaybackPolicy: Binding<PlaybackPolicy?> {
    Binding(
      get: { playbackPolicy },
      set: { if let value = $0 { playbackPolicy = value } }
    )
  }

  private func modelRow(option: SCComboboxOption<String>, selected: Bool) -> some View {
    let model = models.first { $0.id == option.value }
    return HStack(spacing: AppSpacing.sm) {
      Image(systemName: model?.runtime == .local ? "desktopcomputer" : "cloud")
      VStack(alignment: .leading, spacing: 2) {
        Text(option.label)
        if let model {
          Text(model.provider)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      if selected {
        Image(systemName: "checkmark")
      }
    }
  }
}

struct ModeSwitchField: View {
  let title: String
  let description: String
  @Binding var isOn: Bool

  var body: some View {
    SCField(orientation: .horizontal) {
      SCFieldContent {
        SCFieldTitle(title)
        SCFieldDescription(description)
      }
      Toggle(title, isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.scSwitch)
    }
  }
}
