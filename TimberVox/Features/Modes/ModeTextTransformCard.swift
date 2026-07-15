import SwiftUI

struct ModeTextTransformCard: View {
  let mode: DictationMode
  let languageModels: [CatalogModel]
  @Binding var preset: ModeTextTransformPreset
  @Binding var modelID: String
  @Binding var customInstructions: String

  var body: some View {
    SCCard(size: .sm) {
      SCCardHeader {
        SCCardTitle("Text transform")
        SCCardDescription("Control what happens after speech is transcribed.")
      }

      SCCardContent {
        SCFieldGroup(spacing: AppSpacing.lg) {
          presetField

          if mode.usesTextTransform {
            modelField
          }

          if mode.textTransformPreset == .custom {
            promptField
          } else if mode.textTransformPreset.usesAllAvailableContext {
            HStack(spacing: AppSpacing.sm) {
              Image(systemName: "checkmark.circle")
              SCFieldDescription("Uses all available context automatically.")
            }
          }
        }
      }
    }
  }

  private var presetField: some View {
    SCField {
      SCFieldLabel("Preset")
      SCSelect(
        selection: optionalPreset,
        options: ModeTextTransformPreset.allCases.map {
          SCSelectOption(value: $0, label: $0.label)
        }
      )
      SCFieldDescription(mode.textTransformPreset.explanation)
    }
  }

  private var modelField: some View {
    SCField {
      SCFieldLabel("Language model")
      SCCombobox(
        selection: optionalModelID,
        options: languageModels.map {
          SCComboboxOption(
            value: $0.id,
            label: $0.displayName,
            keywords: [$0.provider, $0.upstreamModel],
            group: $0.provider.capitalized
          )
        },
        placeholder: "Choose a language model",
        searchPlaceholder: "Search language models"
      )
    }
  }

  private var promptField: some View {
    SCField {
      SCFieldLabel("Prompt")
      SCTextarea("Describe how TimberVox should transform the transcript.", text: $customInstructions, minHeight: 120)
      SCFieldDescription("The transcript and selected context are supplied separately.")
    }
  }

  private var optionalPreset: Binding<ModeTextTransformPreset?> {
    Binding(
      get: { preset },
      set: { if let value = $0 { preset = value } }
    )
  }

  private var optionalModelID: Binding<String?> {
    Binding(
      get: { modelID },
      set: { if let value = $0 { modelID = value } }
    )
  }
}
