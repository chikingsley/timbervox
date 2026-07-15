import SwiftUI

struct ModePresetPicker: View {
  @Binding var selection: ModeTextTransformPreset?

  var body: some View {
    SCCombobox(
      selection: $selection,
      options: ModeTextTransformPreset.referenceOrder.map {
        SCComboboxOption(value: $0, label: $0.label)
      },
      placeholder: "Choose a preset",
      showsSearchField: false,
      contentWidth: 240,
      contentMaxHeight: 264,
      trigger: { selected, expanded in
        let preset = selected.first?.value
        ModeComboboxTrigger(
          title: preset?.label ?? "Choose a preset",
          isExpanded: expanded
        ) {
          Image(systemName: preset?.systemImage ?? "wand.and.sparkles")
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 16)
        }
      },
      row: { option, selected, _ in
        SCHoverCard(side: .leading) {
          HStack(spacing: 9) {
            Image(systemName: option.value.systemImage)
              .font(.system(size: 12, weight: .medium))
              .frame(width: 16)
            Text(option.label)
              .font(.system(size: 13))
            Spacer(minLength: 6)
            if option.value == .superPrompt {
              Text("Recommended")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.14), in: Capsule())
            }
            Image(systemName: "checkmark")
              .font(.system(size: 11, weight: .semibold))
              .opacity(selected ? 1 : 0)
          }
          .frame(height: 20)
        } content: {
          ModePresetHoverCard(preset: option.value)
        }
      },
      groupHeader: { _ in EmptyView() },
      empty: { Text("No presets found.") }
    )
  }
}

private struct ModePresetHoverCard: View {
  let preset: ModeTextTransformPreset

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: preset.systemImage)
          .font(.system(size: 14, weight: .semibold))
          .frame(width: 28, height: 28)
          .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
        VStack(alignment: .leading, spacing: 2) {
          Text(preset.label).font(.system(size: 14, weight: .semibold))
          if preset == .superPrompt {
            Text("Recommended").font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      Text(preset.explanation)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(width: 256, alignment: .leading)
  }
}
