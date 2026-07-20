import SwiftUI

struct ModeListView: View {
  let modes: [DictationMode]
  let activeModeID: String
  let transcriptionModels: [TranscriptionModelSpec]
  let languageModels: [CatalogModel]
  let onSelect: (String) -> Void
  let onCreate: (ModeTextTransformPreset) -> Void

  private let presetColumns = [
    GridItem(.flexible(), spacing: AppSpacing.sm),
    GridItem(.flexible(), spacing: AppSpacing.sm),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 6) {
          Text("Your modes")
            .font(.system(size: 14, weight: .semibold))

          Image(systemName: "questionmark.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .help(
              "Create modes for different tasks, languages, and recording workflows."
            )
        }

        LazyVStack(spacing: AppSpacing.sm) {
          ForEach(modes) { mode in
            ModeListRow(
              mode: mode,
              isActive: mode.id == activeModeID,
              models: models(for: mode)
            ) {
              onSelect(mode.id)
            }
          }
        }
        .padding(.top, AppSpacing.md)

        Text("Create from a preset")
          .font(.system(size: 14, weight: .semibold))
          .padding(.top, 28)

        Text("Pick the closest format. You can change every setting afterward.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.top, 3)

        LazyVGrid(columns: presetColumns, spacing: AppSpacing.sm) {
          ForEach(ModePresetSuggestion.suggestions) { suggestion in
            ModePresetCard(suggestion: suggestion) {
              onCreate(suggestion.preset)
            }
          }
        }
        .padding(.top, AppSpacing.md)
      }
      .appContentColumn(topInset: AppSpacing.lg, bottomInset: AppSpacing.xl)
    }
  }

  private func models(for mode: DictationMode) -> [ModeProviderReference] {
    var result: [ModeProviderReference] = []
    if let model = transcriptionModels.first(where: { $0.id == mode.audioModelID }) {
      result.append(
        ModeProviderReference(provider: model.provider, runtime: model.runtime)
      )
    }
    if mode.usesTextTransform,
      let model = languageModels.first(where: { $0.id == mode.textTransformModelID })
    {
      result.append(ModeProviderReference(provider: model.provider, runtime: .cloud))
    }
    return result
  }
}

private struct ModeListRow: View {
  let mode: DictationMode
  let isActive: Bool
  let models: [ModeProviderReference]
  let onSelect: () -> Void

  @Environment(\.theme) private var theme
  @State private var isHovered = false

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: AppSpacing.md) {
        Image(systemName: mode.resolvedIconSystemName)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(theme.mutedForeground)
          .frame(width: 24)

        HStack(spacing: AppSpacing.sm) {
          Text(mode.name)
            .font(.system(size: 14, weight: .semibold))
            .lineLimit(1)

          if isActive {
            Circle()
              .fill(Color(red: 0.49, green: 1, blue: 0.35))
              .frame(width: 8, height: 8)
              .accessibilityLabel("Active mode")
          }
        }

        Spacer(minLength: AppSpacing.md)

        HStack(spacing: 6) {
          ForEach(models) { model in
            ModeProviderTile(provider: model.provider, runtime: model.runtime)
          }
        }
      }
      .padding(.horizontal, 20)
      .frame(height: 52)
      .frame(maxWidth: .infinity)
      .background(
        isHovered ? theme.muted : theme.card,
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(isActive ? "mode.list.active" : "mode.list.\(mode.id)")
    .onHover { isHovered = $0 }
  }
}

private struct ModeProviderReference: Identifiable {
  let id = UUID()
  let provider: String
  let runtime: TranscriptionModelRuntime
}

private struct ModePresetSuggestion: Identifiable {
  let preset: ModeTextTransformPreset
  let title: String
  let description: String

  var id: ModeTextTransformPreset { preset }

  static let suggestions = [
    ModePresetSuggestion(
      preset: .message,
      title: "Message",
      description: "Clean up quick messages without changing your tone."
    ),
    ModePresetSuggestion(
      preset: .meeting,
      title: "Meeting Summary",
      description: "Turn a conversation into decisions and follow-ups."
    ),
    ModePresetSuggestion(
      preset: .note,
      title: "Note",
      description: "Shape rough thoughts into clear, structured notes."
    ),
    ModePresetSuggestion(
      preset: .custom,
      title: "Custom",
      description: "Write your own instructions for a repeatable workflow."
    ),
  ]
}

private struct ModePresetCard: View {
  let suggestion: ModePresetSuggestion
  let action: () -> Void

  @Environment(\.theme) private var theme
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: AppSpacing.md) {
        Image(systemName: suggestion.preset.systemImage)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(theme.mutedForeground)
          .frame(width: 32, height: 32)
          .background(theme.muted, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

        VStack(alignment: .leading, spacing: 3) {
          Text(suggestion.title)
            .font(.system(size: 14, weight: .semibold))
          Text(suggestion.description)
            .font(.caption)
            .foregroundStyle(theme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: AppSpacing.sm)

        Image(systemName: "plus")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(theme.mutedForeground)
      }
      .padding(AppSpacing.lg)
      .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
      .background(
        isHovered ? theme.muted : theme.card,
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}
