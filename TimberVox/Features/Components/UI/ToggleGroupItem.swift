// ============================================================
// ToggleGroupItem.swift — swiftcn-ui
// Supplemental source for: toggle-group
// ============================================================
import SwiftUI

// MARK: - Item

/// A native toggle button with a typed value and arbitrary SwiftUI label.
public struct SCToggleGroupItem<Value: Hashable, Label: View>: View {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(\.scToggleGroupContext) private var group
  @FocusState private var isFocused: Bool
  @State private var registrationID = UUID()

  public let value: Value
  private let isDisabled: Bool
  private let variant: SCToggleVariant?
  private let size: SCToggleSize?
  private let spokenLabel: String?
  private let label: Label

  public init(
    value: Value,
    isDisabled: Bool = false,
    variant: SCToggleVariant? = nil,
    size: SCToggleSize? = nil,
    accessibilityLabel: String? = nil,
    @ViewBuilder label: () -> Label
  ) {
    self.value = value
    self.isDisabled = isDisabled
    self.variant = variant
    self.size = size
    self.spokenLabel = accessibilityLabel
    self.label = label()
  }

  public var body: some View {
    labelledButton
      .focused($isFocused)
      .disabled(effectiveDisabled)
      .opacity(effectiveDisabled ? 0.5 : 1)
      .accessibilityAddTraits(isSelected ? .isSelected : [])
      .accessibilityValue(isSelected ? "On" : "Off")
      .onKeyPress(.upArrow) { moveOnVertical(-1) }
      .onKeyPress(.downArrow) { moveOnVertical(1) }
      .onKeyPress(.leftArrow) {
        moveOnHorizontal(layoutDirection == .leftToRight ? -1 : 1)
      }
      .onKeyPress(.rightArrow) {
        moveOnHorizontal(layoutDirection == .leftToRight ? 1 : -1)
      }
      .onAppear { register() }
      .onChange(of: effectiveDisabled) { _, _ in register() }
      .onDisappear { group?.unregister(registrationID) }
  }

  @ViewBuilder
  private var labelledButton: some View {
    if let spokenLabel {
      button.accessibilityLabel(spokenLabel)
    } else {
      button
    }
  }

  private var button: some View {
    Button {
      group?.toggle(AnyHashable(value))
    } label: {
      label
    }
    .buttonStyle(
      SCToggleButtonStyle(
        variant: variant ?? group?.variant ?? .default,
        size: size ?? group?.size ?? .default,
        isOn: isSelected,
        isFocused: isFocused,
        isConnected: group?.spacing == 0
      )
    )
  }

  private var isSelected: Bool {
    group?.values.contains(AnyHashable(value)) ?? false
  }

  private var effectiveDisabled: Bool {
    !isEnabled || isDisabled || (group?.isDisabled ?? false) || group == nil
  }

  private func moveOnVertical(_ offset: Int) -> KeyPress.Result {
    guard group?.orientation == .vertical else { return .ignored }
    group?.move(registrationID, offset)
    return .handled
  }

  private func moveOnHorizontal(_ offset: Int) -> KeyPress.Result {
    guard group?.orientation == .horizontal else { return .ignored }
    group?.move(registrationID, offset)
    return .handled
  }

  private func register() {
    group?.register(registrationID, effectiveDisabled) {
      isFocused = true
    }
  }
}

extension SCToggleGroupItem where Label == AnyView {
  public init(
    value: Value,
    label: String,
    isDisabled: Bool = false,
    variant: SCToggleVariant? = nil,
    size: SCToggleSize? = nil
  ) {
    self.init(
      value: value,
      isDisabled: isDisabled,
      variant: variant,
      size: size,
      accessibilityLabel: label
    ) {
      AnyView(Text(label))
    }
  }

  public init(
    value: Value,
    systemImage: String,
    accessibilityLabel: String? = nil,
    isDisabled: Bool = false,
    variant: SCToggleVariant? = nil,
    size: SCToggleSize? = nil
  ) {
    self.init(
      value: value,
      isDisabled: isDisabled,
      variant: variant,
      size: size,
      accessibilityLabel: accessibilityLabel ?? systemImage
    ) {
      AnyView(Image(systemName: systemImage))
    }
  }

  public init(
    value: Value,
    label: String,
    systemImage: String,
    isDisabled: Bool = false,
    variant: SCToggleVariant? = nil,
    size: SCToggleSize? = nil
  ) {
    self.init(
      value: value,
      isDisabled: isDisabled,
      variant: variant,
      size: size,
      accessibilityLabel: label
    ) {
      AnyView(
        HStack(spacing: 6) {
          Image(systemName: systemImage)
          Text(label)
        }
      )
    }
  }
}
