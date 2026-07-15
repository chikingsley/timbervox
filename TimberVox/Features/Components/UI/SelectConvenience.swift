// ============================================================
// SelectConvenience.swift — swiftcn-ui
// Supplemental source for: select
// ============================================================
import SwiftUI

extension SCSelect {
  /// Creates a caller-controlled single Select.
  public init(
    selection: Binding<Value?>,
    isDisabled: Bool = false,
    isReadOnly: Bool = false,
    isRequired: Bool = false,
    isInvalid: SCFieldInvalidState = .inherited,
    accessibilityLabel: String = "Options",
    itemToStringLabel: @escaping (Value) -> String = { String(describing: $0) },
    onValueChange: ((Value?) -> Void)? = nil,
    @SCSelectBuilder<Value> content: () -> SCSelectComposition<Value>
  ) {
    self.init(
      externalSingleSelection: selection,
      initialSingleSelection: selection.wrappedValue,
      externalMultipleSelection: nil,
      initialMultipleSelection: [],
      mode: .single,
      isDisabled: isDisabled,
      isReadOnly: isReadOnly,
      isRequired: isRequired,
      isInvalid: isInvalid,
      accessibilityLabel: accessibilityLabel,
      itemToStringLabel: itemToStringLabel,
      onValueChange: onValueChange,
      onValuesChange: nil,
      composition: content()
    )
  }

  /// Creates an internally managed single Select.
  public init(
    defaultValue: Value? = nil,
    isDisabled: Bool = false,
    isReadOnly: Bool = false,
    isRequired: Bool = false,
    isInvalid: SCFieldInvalidState = .inherited,
    accessibilityLabel: String = "Options",
    itemToStringLabel: @escaping (Value) -> String = { String(describing: $0) },
    onValueChange: ((Value?) -> Void)? = nil,
    @SCSelectBuilder<Value> content: () -> SCSelectComposition<Value>
  ) {
    self.init(
      externalSingleSelection: nil,
      initialSingleSelection: defaultValue,
      externalMultipleSelection: nil,
      initialMultipleSelection: [],
      mode: .single,
      isDisabled: isDisabled,
      isReadOnly: isReadOnly,
      isRequired: isRequired,
      isInvalid: isInvalid,
      accessibilityLabel: accessibilityLabel,
      itemToStringLabel: itemToStringLabel,
      onValueChange: onValueChange,
      onValuesChange: nil,
      composition: content()
    )
  }

  /// Creates a caller-controlled multiple Select.
  public init(
    selection: Binding<Set<Value>>,
    isDisabled: Bool = false,
    isReadOnly: Bool = false,
    isRequired: Bool = false,
    isInvalid: SCFieldInvalidState = .inherited,
    accessibilityLabel: String = "Options",
    itemToStringLabel: @escaping (Value) -> String = { String(describing: $0) },
    onValuesChange: ((Set<Value>) -> Void)? = nil,
    @SCSelectBuilder<Value> content: () -> SCSelectComposition<Value>
  ) {
    self.init(
      externalSingleSelection: nil,
      initialSingleSelection: nil,
      externalMultipleSelection: selection,
      initialMultipleSelection: selection.wrappedValue,
      mode: .multiple,
      isDisabled: isDisabled,
      isReadOnly: isReadOnly,
      isRequired: isRequired,
      isInvalid: isInvalid,
      accessibilityLabel: accessibilityLabel,
      itemToStringLabel: itemToStringLabel,
      onValueChange: nil,
      onValuesChange: onValuesChange,
      composition: content()
    )
  }

  /// Creates an internally managed multiple Select.
  public init(
    defaultValues: Set<Value>,
    isDisabled: Bool = false,
    isReadOnly: Bool = false,
    isRequired: Bool = false,
    isInvalid: SCFieldInvalidState = .inherited,
    accessibilityLabel: String = "Options",
    itemToStringLabel: @escaping (Value) -> String = { String(describing: $0) },
    onValuesChange: ((Set<Value>) -> Void)? = nil,
    @SCSelectBuilder<Value> content: () -> SCSelectComposition<Value>
  ) {
    self.init(
      externalSingleSelection: nil,
      initialSingleSelection: nil,
      externalMultipleSelection: nil,
      initialMultipleSelection: defaultValues,
      mode: .multiple,
      isDisabled: isDisabled,
      isReadOnly: isReadOnly,
      isRequired: isRequired,
      isInvalid: isInvalid,
      accessibilityLabel: accessibilityLabel,
      itemToStringLabel: itemToStringLabel,
      onValueChange: nil,
      onValuesChange: onValuesChange,
      composition: content()
    )
  }

  /// Existing array convenience, implemented by composing Trigger, Value,
  /// Content, Group, and Item parts over the same Root engine.
  public init(
    selection: Binding<Value?>,
    placeholder: String = "Select…",
    isDisabled: Bool = false,
    isReadOnly: Bool = false,
    isRequired: Bool = false,
    isInvalid: SCFieldInvalidState = .inherited,
    accessibilityLabel: String = "Options",
    onValueChange: ((Value?) -> Void)? = nil,
    options: [SCSelectOption<Value>]
  ) {
    self.init(
      externalSingleSelection: selection,
      initialSingleSelection: selection.wrappedValue,
      externalMultipleSelection: nil,
      initialMultipleSelection: [],
      mode: .single,
      isDisabled: isDisabled,
      isReadOnly: isReadOnly,
      isRequired: isRequired,
      isInvalid: isInvalid,
      accessibilityLabel: accessibilityLabel,
      itemToStringLabel: { value in
        options.first { $0.value == value }?.label ?? String(describing: value)
      },
      onValueChange: onValueChange,
      onValuesChange: nil,
      composition: Self.convenienceComposition(
        placeholder: placeholder,
        options: options
      )
    )
  }

  /// Internally managed array convenience.
  public init(
    defaultValue: Value? = nil,
    placeholder: String = "Select…",
    isDisabled: Bool = false,
    isReadOnly: Bool = false,
    isRequired: Bool = false,
    isInvalid: SCFieldInvalidState = .inherited,
    accessibilityLabel: String = "Options",
    onValueChange: ((Value?) -> Void)? = nil,
    options: [SCSelectOption<Value>]
  ) {
    self.init(
      externalSingleSelection: nil,
      initialSingleSelection: defaultValue,
      externalMultipleSelection: nil,
      initialMultipleSelection: [],
      mode: .single,
      isDisabled: isDisabled,
      isReadOnly: isReadOnly,
      isRequired: isRequired,
      isInvalid: isInvalid,
      accessibilityLabel: accessibilityLabel,
      itemToStringLabel: { value in
        options.first { $0.value == value }?.label ?? String(describing: value)
      },
      onValueChange: onValueChange,
      onValuesChange: nil,
      composition: Self.convenienceComposition(
        placeholder: placeholder,
        options: options
      )
    )
  }
}
