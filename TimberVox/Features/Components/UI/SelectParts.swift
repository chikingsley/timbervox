// ============================================================
// Select.swift — swiftcn-ui
// Depends on: Field.swift · Theme/
// ============================================================
import SwiftUI

// MARK: - Public values

public enum SCSelectSize: CaseIterable, Hashable, Sendable {
  case `default`
  case sm

  internal var minimumHeight: CGFloat {
    switch self {
    case .default: 32
    case .sm: 28
    }
  }

  internal var controlSize: ControlSize {
    switch self {
    case .default: .regular
    case .sm: .small
    }
  }
}

/// The current selection passed to a composable Select Trigger.
public struct SCSelectValueState<Value: Hashable> {
  /// The selected value for a single Select, or the first selected value for
  /// a multiple Select.
  public let value: Value?

  /// Selected values in menu order. Values not represented by an Item follow
  /// in stable display-label order.
  public let values: [Value]

  public let isMultiple: Bool
  public let displayText: String?

  public var isPlaceholder: Bool { values.isEmpty }

  internal init(
    value: Value?,
    values: [Value],
    isMultiple: Bool,
    displayText: String?
  ) {
    self.value = value
    self.values = values
    self.isMultiple = isMultiple
    self.displayText = displayText
  }
}

/// One entry used by the array convenience initializer.
///
/// It is translated into an `SCSelectItem`, so it does not create a second
/// selection engine.
public struct SCSelectOption<Value: Hashable>: Identifiable {
  public let value: Value
  public let label: String
  public let isDisabled: Bool

  public var id: Value { value }

  public init(
    value: Value,
    label: String,
    isDisabled: Bool = false
  ) {
    self.value = value
    self.label = label
    self.isDisabled = isDisabled
  }
}

extension SCSelectOption: Sendable where Value: Sendable {}

// MARK: - Trigger and value

/// The real Menu trigger configuration for an `SCSelect`.
///
/// The content closure receives live typed selection state, allowing either an
/// `SCSelectValue` or an arbitrary rich value view.
public struct SCSelectTrigger<Value: Hashable> {
  internal let size: SCSelectSize
  internal let explicitIsInvalid: SCFieldInvalidState
  internal let expandsHorizontally: Bool
  internal let minimumWidth: CGFloat?
  internal let showsIndicator: Bool
  internal let accessibilityLabel: String?
  internal let content: (SCSelectValueState<Value>) -> AnyView

  public init<Content: View>(
    size: SCSelectSize = .default,
    isInvalid: SCFieldInvalidState = .inherited,
    expandsHorizontally: Bool = false,
    minimumWidth: CGFloat? = nil,
    showsIndicator: Bool = true,
    accessibilityLabel: String? = nil,
    @ViewBuilder content: @escaping (SCSelectValueState<Value>) -> Content
  ) {
    self.size = size
    self.explicitIsInvalid = isInvalid
    self.expandsHorizontally = expandsHorizontally
    self.minimumWidth = minimumWidth.map { max($0, 0) }
    self.showsIndicator = showsIndicator
    self.accessibilityLabel = accessibilityLabel
    self.content = { AnyView(content($0)) }
  }
}

/// A value or placeholder view for use inside `SCSelectTrigger`.
public struct SCSelectValue<Content: View>: View {
  @Environment(\.theme) private var theme

  private let isPlaceholder: Bool
  private let content: Content

  public init<Value: Hashable>(
    _ state: SCSelectValueState<Value>,
    @ViewBuilder content: (SCSelectValueState<Value>) -> Content
  ) {
    self.isPlaceholder = state.isPlaceholder
    self.content = content(state)
  }

  public var body: some View {
    content
      .foregroundStyle(isPlaceholder ? theme.mutedForeground : theme.foreground)
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension SCSelectValue where Content == Text {
  public init<Value: Hashable>(
    _ state: SCSelectValueState<Value>,
    placeholder: String = "Select…"
  ) {
    self.init(state) { state in
      Text(state.displayText ?? placeholder)
    }
  }
}

// MARK: - Content parts

/// One selectable menu item with a typed value, a keyboard text value, and an
/// arbitrary native SwiftUI label.
public struct SCSelectItem<Value: Hashable> {
  internal let value: Value
  internal let textValue: String
  internal let isDisabled: Bool
  internal let label: AnyView

  public init<Label: View>(
    value: Value,
    textValue: String,
    isDisabled: Bool = false,
    @ViewBuilder label: () -> Label
  ) {
    self.value = value
    self.textValue = textValue
    self.isDisabled = isDisabled
    self.label = AnyView(label())
  }

  public init(
    _ title: String,
    value: Value,
    isDisabled: Bool = false
  ) {
    self.init(value: value, textValue: title, isDisabled: isDisabled) {
      Text(title)
    }
  }
}

/// An arbitrary visual and semantic heading inside a Select Group.
public struct SCSelectLabel {
  internal let content: AnyView

  public init<Content: View>(@ViewBuilder content: () -> Content) {
    self.content = AnyView(content())
  }

  public init(_ title: String) {
    self.init { Text(title) }
  }
}

/// A native Select menu separator.
public struct SCSelectSeparator {
  public init() {}
}

indirect enum SCSelectContentNode<Value: Hashable> {
  case item(SCSelectItem<Value>)
  case group(SCSelectGroup<Value>)
  case label(SCSelectLabel)
  case separator
}

/// The opaque result emitted by `SCSelectContentBuilder`.
public struct SCSelectContentBuildResult<Value: Hashable> {
  internal var nodes: [SCSelectContentNode<Value>]

  internal init(nodes: [SCSelectContentNode<Value>] = []) {
    self.nodes = nodes
  }
}

/// Builds Items, Groups, Labels, and Separators while supporting ordinary
/// Swift `if` and `for` composition.
@resultBuilder
public enum SCSelectContentBuilder<Value: Hashable> {
  public static func buildExpression(
    _ item: SCSelectItem<Value>
  ) -> SCSelectContentBuildResult<Value> {
    SCSelectContentBuildResult(nodes: [.item(item)])
  }

  public static func buildExpression(
    _ group: SCSelectGroup<Value>
  ) -> SCSelectContentBuildResult<Value> {
    SCSelectContentBuildResult(nodes: [.group(group)])
  }

  public static func buildExpression(
    _ label: SCSelectLabel
  ) -> SCSelectContentBuildResult<Value> {
    SCSelectContentBuildResult(nodes: [.label(label)])
  }

  public static func buildExpression(
    _: SCSelectSeparator
  ) -> SCSelectContentBuildResult<Value> {
    SCSelectContentBuildResult(nodes: [.separator])
  }

  public static func buildBlock(
    _ components: SCSelectContentBuildResult<Value>...
  ) -> SCSelectContentBuildResult<Value> {
    SCSelectContentBuildResult(nodes: components.flatMap(\.nodes))
  }

  public static func buildOptional(
    _ component: SCSelectContentBuildResult<Value>?
  ) -> SCSelectContentBuildResult<Value> {
    component ?? SCSelectContentBuildResult()
  }

  public static func buildEither(
    first component: SCSelectContentBuildResult<Value>
  ) -> SCSelectContentBuildResult<Value> {
    component
  }

  public static func buildEither(
    second component: SCSelectContentBuildResult<Value>
  ) -> SCSelectContentBuildResult<Value> {
    component
  }

  public static func buildArray(
    _ components: [SCSelectContentBuildResult<Value>]
  ) -> SCSelectContentBuildResult<Value> {
    SCSelectContentBuildResult(nodes: components.flatMap(\.nodes))
  }

  public static func buildLimitedAvailability(
    _ component: SCSelectContentBuildResult<Value>
  ) -> SCSelectContentBuildResult<Value> {
    component
  }
}

/// The popup content declaration consumed by an `SCSelect` Root.
///
/// SwiftUI's native Menu owns portal placement, dismissal, scrolling, scroll
/// arrows, keyboard navigation, typeahead, pointer interaction, and touch.
public struct SCSelectContent<Value: Hashable> {
  internal let nodes: [SCSelectContentNode<Value>]

  public init(
    @SCSelectContentBuilder<Value> content: () -> SCSelectContentBuildResult<Value>
  ) {
    self.nodes = content().nodes
  }

  internal init(nodes: [SCSelectContentNode<Value>]) {
    self.nodes = nodes
  }
}

/// A native Section-backed group. Put an `SCSelectLabel` anywhere in its
/// builder to supply the Section header.
public struct SCSelectGroup<Value: Hashable> {
  internal let nodes: [SCSelectContentNode<Value>]

  public init(
    @SCSelectContentBuilder<Value> content: () -> SCSelectContentBuildResult<Value>
  ) {
    self.nodes = content().nodes
  }

  public init(
    _ title: String,
    @SCSelectContentBuilder<Value> content: () -> SCSelectContentBuildResult<Value>
  ) {
    self.nodes = [.label(SCSelectLabel(title))] + content().nodes
  }

  internal var label: SCSelectLabel? {
    nodes.compactMap { node in
      if case .label(let label) = node { return label }
      return nil
    }.first
  }

  internal var contentNodes: [SCSelectContentNode<Value>] {
    nodes.filter { node in
      if case .label = node { return false }
      return true
    }
  }
}
