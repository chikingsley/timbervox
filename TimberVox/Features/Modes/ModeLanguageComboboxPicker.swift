import SwiftUI

struct ModeLanguageComboboxPicker: View {
  @Binding var selection: String?
  let options: [SCComboboxOption<String>]

  var body: some View {
    SCCombobox(
      selection: $selection,
      options: options,
      placeholder: "Automatic",
      showsSearchField: false,
      contentWidth: 240,
      contentMaxHeight: 240,
      trigger: { selected, expanded in
        ModeComboboxTrigger(
          title: selected.first?.label ?? "Automatic",
          isExpanded: expanded
        ) {
          EmptyView()
        }
      },
      row: { option, selected, _ in
        HStack(spacing: 8) {
          Text(option.label)
            .font(.system(size: 13))
          Spacer(minLength: 8)
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .semibold))
            .opacity(selected ? 1 : 0)
        }
        .frame(height: 20)
      },
      groupHeader: { _ in EmptyView() },
      empty: { Text("No languages found.") }
    )
  }
}
