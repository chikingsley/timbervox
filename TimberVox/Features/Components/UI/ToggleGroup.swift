// ============================================================
// ToggleGroup.swift — swiftcn-ui
// Depends on: Theme/ · Toggle.swift
// ============================================================
import SwiftUI

// MARK: - Configuration

/// The visual axis and arrow-key axis of a toggle group.
public enum SCToggleGroupOrientation: Hashable, Sendable {
  case horizontal
  case vertical
}

// MARK: - Shared state

private final class SCToggleGroupKeyboardCoordinator {
  private struct Entry {
    let id: UUID
    var isDisabled: Bool
    var focus: () -> Void
  }

  private var entries: [Entry] = []

  func register(id: UUID, isDisabled: Bool, focus: @escaping () -> Void) {
    if let index = entries.firstIndex(where: { $0.id == id }) {
      entries[index].isDisabled = isDisabled
      entries[index].focus = focus
    } else {
      entries.append(Entry(id: id, isDisabled: isDisabled, focus: focus))
    }
  }

  func unregister(id: UUID) {
    entries.removeAll { $0.id == id }
  }

  func move(from id: UUID, offset: Int, loops: Bool) {
    guard
      !entries.isEmpty,
      offset != 0,
      let currentIndex = entries.firstIndex(where: { $0.id == id })
    else { return }

    for step in 1...entries.count {
      let candidate = currentIndex + offset * step
      let index: Int
      if loops {
        index = (candidate % entries.count + entries.count) % entries.count
      } else {
        guard entries.indices.contains(candidate) else { return }
        index = candidate
      }
      guard !entries[index].isDisabled else { continue }
      entries[index].focus()
      return
    }
  }
}

struct SCToggleGroupContext {
  var values: Set<AnyHashable> = []
  var variant: SCToggleVariant = .default
  var size: SCToggleSize = .default
  var orientation: SCToggleGroupOrientation = .horizontal
  var spacing: CGFloat = 2
  var isDisabled = false
  var toggle: (AnyHashable) -> Void = { _ in }
  var register: (UUID, Bool, @escaping () -> Void) -> Void = { _, _, _ in }
  var unregister: (UUID) -> Void = { _ in }
  var move: (UUID, Int) -> Void = { _, _ in }
}

private struct SCToggleGroupContextKey: EnvironmentKey {
  static var defaultValue: SCToggleGroupContext? { nil }
}

extension EnvironmentValues {
  var scToggleGroupContext: SCToggleGroupContext? {
    get { self[SCToggleGroupContextKey.self] }
    set { self[SCToggleGroupContextKey.self] = newValue }
  }
}

// MARK: - Root

/// Provides shared single- or multiple-selection state to composed toggle items.
///
/// The builder form follows shadcn's Root/Item composition and accepts arbitrary
/// SwiftUI labels:
///
///     SCToggleGroup(selection: $alignment, variant: .outline, spacing: 0) {
///         SCToggleGroupItem(value: Alignment.left) {
///             Image(systemName: "text.alignleft")
///         }
///         SCToggleGroupItem(value: Alignment.center) {
///             Image(systemName: "text.aligncenter")
///         }
///     }
///
/// Use a `Binding<Value?>` for single selection or `Binding<Set<Value>>` for
/// multiple selection. The `defaultValue` and `defaultValues` initializers own
/// state internally. Existing array-based call sites remain available as thin
/// connected-outline compositions over the same root and item engine.
public struct SCToggleGroup<Value: Hashable, Content: View>: View {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.theme) private var theme
  @State private var internalValues: Set<Value>
  @State private var keyboard = SCToggleGroupKeyboardCoordinator()

  private enum Selection {
    case single(Binding<Value?>?)
    case multiple(Binding<Set<Value>>?)
  }

  private let selection: Selection
  private let variant: SCToggleVariant
  private let size: SCToggleSize
  private let spacing: CGFloat
  private let orientation: SCToggleGroupOrientation
  private let loopsFocus: Bool
  private let isDisabled: Bool
  private let accessibilityLabel: String
  private let onValuesChange: (Set<Value>) -> Void
  private let content: Content

  /// Creates a caller-controlled single-selection group.
  public init(
    selection: Binding<Value?>,
    variant: SCToggleVariant = .default,
    size: SCToggleSize = .default,
    spacing: CGFloat = 2,
    orientation: SCToggleGroupOrientation = .horizontal,
    loopsFocus: Bool = true,
    isDisabled: Bool = false,
    accessibilityLabel: String = "Toggle group",
    onValueChange: ((Value?) -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.selection = .single(selection)
    self._internalValues = State(initialValue: Set(selection.wrappedValue.map { [$0] } ?? []))
    self.variant = variant
    self.size = size
    self.spacing = max(spacing, 0)
    self.orientation = orientation
    self.loopsFocus = loopsFocus
    self.isDisabled = isDisabled
    self.accessibilityLabel = accessibilityLabel
    self.onValuesChange = { onValueChange?($0.first) }
    self.content = content()
  }

  /// Creates an internally managed single-selection group.
  public init(
    defaultValue: Value? = nil,
    variant: SCToggleVariant = .default,
    size: SCToggleSize = .default,
    spacing: CGFloat = 2,
    orientation: SCToggleGroupOrientation = .horizontal,
    loopsFocus: Bool = true,
    isDisabled: Bool = false,
    accessibilityLabel: String = "Toggle group",
    onValueChange: ((Value?) -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.selection = .single(nil)
    self._internalValues = State(initialValue: Set(defaultValue.map { [$0] } ?? []))
    self.variant = variant
    self.size = size
    self.spacing = max(spacing, 0)
    self.orientation = orientation
    self.loopsFocus = loopsFocus
    self.isDisabled = isDisabled
    self.accessibilityLabel = accessibilityLabel
    self.onValuesChange = { onValueChange?($0.first) }
    self.content = content()
  }

  /// Creates a caller-controlled multiple-selection group.
  public init(
    selection: Binding<Set<Value>>,
    variant: SCToggleVariant = .default,
    size: SCToggleSize = .default,
    spacing: CGFloat = 2,
    orientation: SCToggleGroupOrientation = .horizontal,
    loopsFocus: Bool = true,
    isDisabled: Bool = false,
    accessibilityLabel: String = "Toggle group",
    onValueChange: ((Set<Value>) -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.selection = .multiple(selection)
    self._internalValues = State(initialValue: selection.wrappedValue)
    self.variant = variant
    self.size = size
    self.spacing = max(spacing, 0)
    self.orientation = orientation
    self.loopsFocus = loopsFocus
    self.isDisabled = isDisabled
    self.accessibilityLabel = accessibilityLabel
    self.onValuesChange = { onValueChange?($0) }
    self.content = content()
  }

  /// Creates an internally managed multiple-selection group.
  public init(
    defaultValues: Set<Value>,
    variant: SCToggleVariant = .default,
    size: SCToggleSize = .default,
    spacing: CGFloat = 2,
    orientation: SCToggleGroupOrientation = .horizontal,
    loopsFocus: Bool = true,
    isDisabled: Bool = false,
    accessibilityLabel: String = "Toggle group",
    onValueChange: ((Set<Value>) -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.selection = .multiple(nil)
    self._internalValues = State(initialValue: defaultValues)
    self.variant = variant
    self.size = size
    self.spacing = max(spacing, 0)
    self.orientation = orientation
    self.loopsFocus = loopsFocus
    self.isDisabled = isDisabled
    self.accessibilityLabel = accessibilityLabel
    self.onValuesChange = { onValueChange?($0) }
    self.content = content()
  }

  public var body: some View {
    laidOutContent
      .environment(\.scToggleGroupContext, context)
      .disabled(isDisabled)
      .clipShape(groupShape)
      .overlay {
        if spacing == 0, variant == .outline {
          groupShape.strokeBorder(theme.border)
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel(accessibilityLabel)
  }

  @ViewBuilder
  private var laidOutContent: some View {
    switch orientation {
    case .horizontal:
      HStack(spacing: effectiveSpacing) { content }
    case .vertical:
      VStack(spacing: effectiveSpacing) { content }
    }
  }

  private var currentValues: Set<Value> {
    switch selection {
    case .single(let binding):
      if let value = binding?.wrappedValue { [value] } else { internalValues }
    case .multiple(let binding): binding?.wrappedValue ?? internalValues
    }
  }

  private var context: SCToggleGroupContext {
    SCToggleGroupContext(
      values: Set(currentValues.map { AnyHashable($0) }),
      variant: variant,
      size: size,
      orientation: orientation,
      spacing: spacing,
      isDisabled: isDisabled,
      toggle: toggle,
      register: { id, isDisabled, focus in
        keyboard.register(id: id, isDisabled: isDisabled, focus: focus)
      },
      unregister: { id in keyboard.unregister(id: id) },
      move: { id, offset in
        keyboard.move(from: id, offset: offset, loops: loopsFocus)
      }
    )
  }

  private var effectiveSpacing: CGFloat {
    spacing == 0 && variant == .outline ? -1 : spacing
  }

  private var groupShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
  }

  private func toggle(_ erasedValue: AnyHashable) {
    guard
      isEnabled,
      !isDisabled,
      let value = erasedValue.base as? Value
    else { return }

    var next = currentValues
    switch selection {
    case .single:
      next = next.contains(value) ? [] : [value]
    case .multiple:
      if next.contains(value) {
        next.remove(value)
      } else {
        next.insert(value)
      }
    }

    switch selection {
    case .single(let binding):
      if let binding {
        binding.wrappedValue = next.first
      } else {
        internalValues = next
      }
    case .multiple(let binding):
      if let binding {
        binding.wrappedValue = next
      } else {
        internalValues = next
      }
    }
    onValuesChange(next)
  }
}
