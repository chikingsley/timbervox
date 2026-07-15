// ============================================================
// Select.swift — swiftcn-ui
// Depends on: Field.swift · Theme/
// ============================================================
import SwiftUI

// MARK: - Root builder

enum SCSelectRootNode<Value: Hashable> {
  case trigger(SCSelectTrigger<Value>)
  case content(SCSelectContent<Value>)
}

/// The opaque result emitted by `SCSelectBuilder`.
public struct SCSelectComposition<Value: Hashable> {
  internal var nodes: [SCSelectRootNode<Value>]

  internal init(nodes: [SCSelectRootNode<Value>] = []) {
    self.nodes = nodes
  }
}

/// Builds the documented Root → Trigger/Value + Content composition.
@resultBuilder
public enum SCSelectBuilder<Value: Hashable> {
  public static func buildExpression(
    _ trigger: SCSelectTrigger<Value>
  ) -> SCSelectComposition<Value> {
    SCSelectComposition(nodes: [.trigger(trigger)])
  }

  public static func buildExpression(
    _ content: SCSelectContent<Value>
  ) -> SCSelectComposition<Value> {
    SCSelectComposition(nodes: [.content(content)])
  }

  public static func buildBlock(
    _ components: SCSelectComposition<Value>...
  ) -> SCSelectComposition<Value> {
    SCSelectComposition(nodes: components.flatMap(\.nodes))
  }

  public static func buildOptional(
    _ component: SCSelectComposition<Value>?
  ) -> SCSelectComposition<Value> {
    component ?? SCSelectComposition()
  }

  public static func buildEither(
    first component: SCSelectComposition<Value>
  ) -> SCSelectComposition<Value> {
    component
  }

  public static func buildEither(
    second component: SCSelectComposition<Value>
  ) -> SCSelectComposition<Value> {
    component
  }

  public static func buildArray(
    _ components: [SCSelectComposition<Value>]
  ) -> SCSelectComposition<Value> {
    SCSelectComposition(nodes: components.flatMap(\.nodes))
  }

  public static func buildLimitedAvailability(
    _ component: SCSelectComposition<Value>
  ) -> SCSelectComposition<Value> {
    component
  }
}

// MARK: - Root

enum SCSelectSelectionMode {
  case single
  case multiple
}

/// A typed, composable Select backed by the platform Menu primitive.
///
/// There is one engine for controlled and internally managed single or
/// multiple selection. Native Menu supplies the real popup, focus, keyboard,
/// typeahead, scrolling, pointer/touch behavior, dismissal, and accessibility.
public struct SCSelect<Value: Hashable>: View {
  @Environment(\.isEnabled) private var environmentIsEnabled
  @Environment(\.scFieldInvalid) private var fieldIsInvalid
  @FocusState private var isFocused: Bool

  @State private var internalSingleSelection: Value?
  @State private var internalMultipleSelection: Set<Value>

  private let externalSingleSelection: Binding<Value?>?
  private let externalMultipleSelection: Binding<Set<Value>>?
  private let mode: SCSelectSelectionMode
  private let isDisabled: Bool
  private let isReadOnly: Bool
  private let isRequired: Bool
  private let explicitIsInvalid: SCFieldInvalidState
  private let accessibilityLabel: String
  private let itemToStringLabel: (Value) -> String
  private let onValueChange: ((Value?) -> Void)?
  private let onValuesChange: ((Set<Value>) -> Void)?
  private let composition: SCSelectComposition<Value>

  init(
    externalSingleSelection: Binding<Value?>?,
    initialSingleSelection: Value?,
    externalMultipleSelection: Binding<Set<Value>>?,
    initialMultipleSelection: Set<Value>,
    mode: SCSelectSelectionMode,
    isDisabled: Bool,
    isReadOnly: Bool,
    isRequired: Bool,
    isInvalid: SCFieldInvalidState,
    accessibilityLabel: String,
    itemToStringLabel: @escaping (Value) -> String,
    onValueChange: ((Value?) -> Void)?,
    onValuesChange: ((Set<Value>) -> Void)?,
    composition: SCSelectComposition<Value>
  ) {
    self._internalSingleSelection = State(initialValue: initialSingleSelection)
    self._internalMultipleSelection = State(initialValue: initialMultipleSelection)
    self.externalSingleSelection = externalSingleSelection
    self.externalMultipleSelection = externalMultipleSelection
    self.mode = mode
    self.isDisabled = isDisabled
    self.isReadOnly = isReadOnly
    self.isRequired = isRequired
    self.explicitIsInvalid = isInvalid
    self.accessibilityLabel = accessibilityLabel
    self.itemToStringLabel = itemToStringLabel
    self.onValueChange = onValueChange
    self.onValuesChange = onValuesChange
    self.composition = composition
  }

  public var body: some View {
    let state = valueState
    let trigger = resolvedTrigger

    Menu {
      SCSelectNodeList(
        nodes: contentNodes,
        mode: mode,
        isReadOnly: isReadOnly,
        isSelected: isSelected,
        activate: activate
      )
    } label: {
      SCSelectTriggerBody(
        trigger: trigger,
        state: state,
        isFocused: isFocused,
        isInvalid: trigger.explicitIsInvalid.resolve(inherited: resolvedIsInvalid)
      )
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .controlSize(trigger.size.controlSize)
    .focused($isFocused)
    .disabled(isDisabled)
    .opacity(isActuallyEnabled ? 1 : 0.5)
    .accessibilityLabel(trigger.accessibilityLabel ?? accessibilityLabel)
    .accessibilityValue(state.displayText ?? "No selection")
    .accessibilityHint(accessibilityHint)
  }

  private var resolvedTrigger: SCSelectTrigger<Value> {
    composition.nodes.compactMap { node in
      if case .trigger(let trigger) = node { return trigger }
      return nil
    }.last
      ?? SCSelectTrigger { state in
        SCSelectValue(state)
      }
  }

  private var contentNodes: [SCSelectContentNode<Value>] {
    composition.nodes.flatMap { node in
      if case .content(let content) = node { return content.nodes }
      return []
    }
  }

  private var allItems: [SCSelectItem<Value>] {
    Self.items(in: contentNodes)
  }

  private static func items(
    in nodes: [SCSelectContentNode<Value>]
  ) -> [SCSelectItem<Value>] {
    return nodes.flatMap { node -> [SCSelectItem<Value>] in
      switch node {
      case .item(let item):
        return [item]
      case .group(let group):
        return items(in: group.contentNodes)
      case .label, .separator:
        return []
      }
    }
  }

  private var singleSelection: Value? {
    externalSingleSelection?.wrappedValue ?? internalSingleSelection
  }

  private var multipleSelection: Set<Value> {
    externalMultipleSelection?.wrappedValue ?? internalMultipleSelection
  }

  private var orderedSelectedValues: [Value] {
    switch mode {
    case .single:
      return singleSelection.map { [$0] } ?? []
    case .multiple:
      var values: [Value] = []
      var seen: Set<Value> = []
      for item in allItems where multipleSelection.contains(item.value) {
        if seen.insert(item.value).inserted {
          values.append(item.value)
        }
      }
      values.append(
        contentsOf:
          multipleSelection
          .filter { !seen.contains($0) }
          .sorted { itemToStringLabel($0) < itemToStringLabel($1) }
      )
      return values
    }
  }

  private var valueState: SCSelectValueState<Value> {
    let values = orderedSelectedValues
    let displayText: String?
    switch values.count {
    case 0:
      displayText = nil
    case 1:
      displayText = label(for: values[0])
    default:
      displayText = "\(values.count) selected"
    }
    return SCSelectValueState(
      value: mode == .single ? values.first : nil,
      values: values,
      isMultiple: mode == .multiple,
      displayText: displayText
    )
  }

  private func label(for value: Value) -> String {
    allItems.first { $0.value == value }?.textValue ?? itemToStringLabel(value)
  }

  private func isSelected(_ value: Value) -> Bool {
    switch mode {
    case .single: singleSelection == value
    case .multiple: multipleSelection.contains(value)
    }
  }

  private func activate(_ value: Value) {
    guard isActuallyEnabled, !isReadOnly else { return }
    switch mode {
    case .single:
      guard singleSelection != value else { return }
      if let externalSingleSelection {
        externalSingleSelection.wrappedValue = value
      } else {
        internalSingleSelection = value
      }
      onValueChange?(value)
    case .multiple:
      var updated = multipleSelection
      if updated.contains(value) {
        if isRequired, updated.count == 1 { return }
        updated.remove(value)
      } else {
        updated.insert(value)
      }
      if let externalMultipleSelection {
        externalMultipleSelection.wrappedValue = updated
      } else {
        internalMultipleSelection = updated
      }
      onValuesChange?(updated)
    }
  }

  private var resolvedIsInvalid: Bool {
    explicitIsInvalid.resolve(inherited: fieldIsInvalid)
  }

  private var isActuallyEnabled: Bool {
    environmentIsEnabled && !isDisabled
  }

  private var accessibilityHint: String {
    if resolvedIsInvalid { return "Invalid selection" }
    if isReadOnly { return "Read only" }
    if isRequired { return "Required" }
    return ""
  }

  static func convenienceComposition(
    placeholder: String,
    options: [SCSelectOption<Value>]
  ) -> SCSelectComposition<Value> {
    let trigger = SCSelectTrigger<Value>(expandsHorizontally: true) { state in
      SCSelectValue(state, placeholder: placeholder)
    }
    let items = options.map { option in
      SCSelectContentNode.item(
        SCSelectItem(
          option.label,
          value: option.value,
          isDisabled: option.isDisabled
        )
      )
    }
    return SCSelectComposition(nodes: [
      .trigger(trigger),
      .content(SCSelectContent(nodes: items)),
    ])
  }
}

extension SCSelect where Value == String {
  public init(
    selection: Binding<String?>,
    placeholder: String = "Select…",
    isDisabled: Bool = false,
    isReadOnly: Bool = false,
    isRequired: Bool = false,
    isInvalid: SCFieldInvalidState = .inherited,
    accessibilityLabel: String = "Options",
    onValueChange: ((String?) -> Void)? = nil,
    options: [String]
  ) {
    self.init(
      selection: selection,
      placeholder: placeholder,
      isDisabled: isDisabled,
      isReadOnly: isReadOnly,
      isRequired: isRequired,
      isInvalid: isInvalid,
      accessibilityLabel: accessibilityLabel,
      onValueChange: onValueChange,
      options: options.map { SCSelectOption(value: $0, label: $0) }
    )
  }

  public init(
    defaultValue: String? = nil,
    placeholder: String = "Select…",
    isDisabled: Bool = false,
    isReadOnly: Bool = false,
    isRequired: Bool = false,
    isInvalid: SCFieldInvalidState = .inherited,
    accessibilityLabel: String = "Options",
    onValueChange: ((String?) -> Void)? = nil,
    options: [String]
  ) {
    self.init(
      defaultValue: defaultValue,
      placeholder: placeholder,
      isDisabled: isDisabled,
      isReadOnly: isReadOnly,
      isRequired: isRequired,
      isInvalid: isInvalid,
      accessibilityLabel: accessibilityLabel,
      onValueChange: onValueChange,
      options: options.map { SCSelectOption(value: $0, label: $0) }
    )
  }
}
