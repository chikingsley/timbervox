// ============================================================
// SelectRendering.swift — swiftcn-ui
// Supplemental source for: select
// ============================================================
import SwiftUI

// MARK: - Rendering

struct SCSelectTriggerBody<Value: Hashable>: View {
  @Environment(\.theme) private var theme
  @Environment(\.scGroupedControlOrientation) private var groupOrientation

  let trigger: SCSelectTrigger<Value>
  let state: SCSelectValueState<Value>
  let isFocused: Bool
  let isInvalid: Bool

  var body: some View {
    HStack(spacing: 8) {
      trigger.content(state)
      if trigger.showsIndicator {
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption)
          .foregroundStyle(theme.mutedForeground)
          .accessibilityHidden(true)
      }
    }
    .padding(.horizontal, 10)
    .frame(
      minWidth: trigger.minimumWidth,
      maxWidth: trigger.expandsHorizontally ? .infinity : nil,
      minHeight: trigger.size.minimumHeight,
      alignment: .leading
    )
    .background(controlSurface, in: shape)
    .overlay { shape.strokeBorder(borderColor, lineWidth: borderWidth) }
    .contentShape(shape)
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: groupOrientation == nil ? max(theme.radius - 2, 4) : 0,
      style: .continuous
    )
  }

  private var controlSurface: Color {
    .adaptive(
      light: .white,
      dark: Color(red: 48 / 255, green: 48 / 255, blue: 48 / 255)
    )
  }

  private var borderColor: Color {
    if isInvalid { return theme.destructive }
    if isFocused { return theme.ring.opacity(0.5) }
    return theme.input
  }

  private var borderWidth: CGFloat {
    isFocused ? 3 : 1
  }
}

struct SCSelectNodeList<Value: Hashable>: View {
  @Environment(\.theme) private var theme

  let nodes: [SCSelectContentNode<Value>]
  let mode: SCSelectSelectionMode
  let isReadOnly: Bool
  let isSelected: (Value) -> Bool
  let activate: (Value) -> Void

  @ViewBuilder
  var body: some View {
    ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
      switch node {
      case .item(let item):
        SCSelectMenuItem(
          item: item,
          mode: mode,
          isReadOnly: isReadOnly,
          isSelected: isSelected(item.value)
        ) { activate(item.value) }
      case .group(let group):
        Section {
          SCSelectNodeList(
            nodes: group.contentNodes,
            mode: mode,
            isReadOnly: isReadOnly,
            isSelected: isSelected,
            activate: activate
          )
        } header: {
          if let label = group.label {
            label.content
              .foregroundStyle(theme.mutedForeground)
          }
        }
      case .label(let label):
        label.content
          .font(.caption)
          .foregroundStyle(theme.mutedForeground)
          .accessibilityAddTraits(.isHeader)
      case .separator:
        Divider()
      }
    }
  }
}

struct SCSelectMenuItem<Value: Hashable>: View {
  let item: SCSelectItem<Value>
  let mode: SCSelectSelectionMode
  let isReadOnly: Bool
  let isSelected: Bool
  let activate: () -> Void

  @ViewBuilder
  var body: some View {
    switch mode {
    case .single:
      Button(action: activate) {
        Label {
          item.label
        } icon: {
          Image(systemName: "checkmark")
            .opacity(isSelected ? 1 : 0)
        }
      }
      .disabled(isReadOnly || item.isDisabled)
      .accessibilityLabel(item.textValue)
      .accessibilityAddTraits(isSelected ? .isSelected : [])
    case .multiple:
      Toggle(
        isOn: Binding(
          get: { isSelected },
          set: { _ in activate() }
        )
      ) {
        item.label
      }
      .disabled(isReadOnly || item.isDisabled)
      .accessibilityLabel(item.textValue)
    }
  }
}
