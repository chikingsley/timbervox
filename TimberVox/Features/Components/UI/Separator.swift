// ============================================================
// Separator.swift — swiftcn-ui
// Depends on: Theme/
// ============================================================
import SwiftUI

// MARK: - Component

/// A 1pt rule that visually or semantically divides content, in the theme's border color.
/// Horizontal separators fill the available width; vertical ones fill the
/// available height. Separators are exposed to accessibility by default; use
/// `isDecorative: true` only for a purely visual line. The labeled form accepts
/// arbitrary centered content between two rules.
///
///     SCSeparator()
///     SCSeparator(.vertical)
///     SCSeparator(label: "or continue with")
public struct SCSeparator: View {
  @Environment(\.theme) private var theme

  private let axis: Axis
  private let isDecorative: Bool
  private let semanticLabel: String?
  private let label: AnyView?

  public init(
    _ axis: Axis = .horizontal,
    isDecorative: Bool = false,
    accessibilityLabel: String = "Separator"
  ) {
    self.axis = axis
    self.isDecorative = isDecorative
    self.semanticLabel = accessibilityLabel
    self.label = nil
  }

  /// A horizontal separator with a centered label.
  public init(
    label: String,
    isDecorative: Bool = false
  ) {
    self.axis = .horizontal
    self.isDecorative = isDecorative
    self.semanticLabel = label
    self.label = AnyView(Text(label))
  }

  /// A horizontal separator with arbitrary centered content.
  public init<Label: View>(
    isDecorative: Bool = false,
    accessibilityLabel: String? = nil,
    @ViewBuilder label: () -> Label
  ) {
    self.axis = .horizontal
    self.isDecorative = isDecorative
    self.semanticLabel = accessibilityLabel
    self.label = AnyView(label())
  }

  public var body: some View {
    if let label {
      HStack(spacing: 16) {
        line
        label
          .font(.caption)
          .foregroundStyle(theme.mutedForeground)
          .lineLimit(1)
          .fixedSize()
        line
      }
      .modifier(accessibilityModifier)
    } else {
      line
        .modifier(accessibilityModifier)
    }
  }

  @ViewBuilder
  private var line: some View {
    switch axis {
    case .horizontal:
      theme.border
        .frame(height: 1)
        .frame(maxWidth: .infinity)
    case .vertical:
      theme.border
        .frame(width: 1)
        .frame(maxHeight: .infinity)
    }
  }

  private var accessibilityModifier: SCSeparatorAccessibilityModifier {
    SCSeparatorAccessibilityModifier(
      isDecorative: isDecorative,
      label: semanticLabel,
      orientation: axis == .horizontal ? "Horizontal" : "Vertical"
    )
  }
}

private struct SCSeparatorAccessibilityModifier: ViewModifier {
  let isDecorative: Bool
  let label: String?
  let orientation: String

  @ViewBuilder
  func body(content: Content) -> some View {
    if isDecorative {
      content.accessibilityHidden(true)
    } else if let label {
      content
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(orientation)
    } else {
      content
        .accessibilityElement(children: .combine)
        .accessibilityValue(orientation)
    }
  }
}
