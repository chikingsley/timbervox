import SwiftUI

/// An independent tap action inside an explicitly interactive combobox row.
/// Use it for the row's selection region and for accessories such as favorite
/// or download buttons.
public struct SCComboboxRowAction<Label: View>: View {
  private let accessibilityLabel: String
  private let isDisabled: Bool
  private let isSelected: Bool
  private let action: () -> Void
  private let label: Label

  public init(
    accessibilityLabel: String,
    isDisabled: Bool = false,
    isSelected: Bool = false,
    action: @escaping () -> Void,
    @ViewBuilder label: () -> Label
  ) {
    self.accessibilityLabel = accessibilityLabel
    self.isDisabled = isDisabled
    self.isSelected = isSelected
    self.action = action
    self.label = label()
  }

  public var body: some View {
    label
      .contentShape(Rectangle())
      .onTapGesture {
        guard !isDisabled else { return }
        action()
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityAddTraits(.isButton)
      .accessibilityAddTraits(isSelected ? .isSelected : [])
      .accessibilityAction {
        guard !isDisabled else { return }
        action()
      }
      .opacity(isDisabled ? 0.5 : 1)
  }
}
