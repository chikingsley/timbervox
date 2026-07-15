// ============================================================
// ToggleGroupConvenience.swift — swiftcn-ui
// Supplemental source for: toggle-group
// ============================================================
import SwiftUI

// MARK: - Array conveniences

extension SCToggleGroup where Content == AnyView {
  /// Compatibility composition for the original connected outline API.
  public init(
    selection: Binding<Value?>,
    items: [SCToggleGroupItem<Value, AnyView>],
    variant: SCToggleVariant = .outline,
    size: SCToggleSize = .default,
    spacing: CGFloat = 0,
    orientation: SCToggleGroupOrientation = .horizontal,
    loopsFocus: Bool = true,
    isDisabled: Bool = false,
    accessibilityLabel: String = "Toggle group",
    onValueChange: ((Value?) -> Void)? = nil
  ) {
    self.init(
      selection: selection,
      variant: variant,
      size: size,
      spacing: spacing,
      orientation: orientation,
      loopsFocus: loopsFocus,
      isDisabled: isDisabled,
      accessibilityLabel: accessibilityLabel,
      onValueChange: onValueChange
    ) {
      AnyView(ForEach(items, id: \.value) { item in item })
    }
  }

  /// Compatibility composition for the original connected outline API.
  public init(
    selection: Binding<Set<Value>>,
    items: [SCToggleGroupItem<Value, AnyView>],
    variant: SCToggleVariant = .outline,
    size: SCToggleSize = .default,
    spacing: CGFloat = 0,
    orientation: SCToggleGroupOrientation = .horizontal,
    loopsFocus: Bool = true,
    isDisabled: Bool = false,
    accessibilityLabel: String = "Toggle group",
    onValueChange: ((Set<Value>) -> Void)? = nil
  ) {
    self.init(
      selection: selection,
      variant: variant,
      size: size,
      spacing: spacing,
      orientation: orientation,
      loopsFocus: loopsFocus,
      isDisabled: isDisabled,
      accessibilityLabel: accessibilityLabel,
      onValueChange: onValueChange
    ) {
      AnyView(ForEach(items, id: \.value) { item in item })
    }
  }
}
