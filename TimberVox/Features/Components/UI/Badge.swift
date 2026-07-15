// ============================================================
// Badge.swift — swiftcn-ui
// Depends on: Theme/
// ============================================================
import SwiftUI

// MARK: - Variants

public enum SCBadgeVariant: CaseIterable, Sendable {
  case `default`, secondary, destructive, outline, ghost, link
}

// MARK: - Static badge

/// Displays arbitrary content as a compact status badge.
///
/// Use the `scBadge` button style or view modifier when a native `Button` or
/// `Link` must own activation rather than placing an action inside this view.
public struct SCBadge<Content: View>: View {
  private let variant: SCBadgeVariant
  private let isInvalid: Bool
  private let backgroundColor: Color?
  private let foregroundColor: Color?
  private let borderColor: Color?
  private let content: Content

  public init(
    variant: SCBadgeVariant = .default,
    isInvalid: Bool = false,
    backgroundColor: Color? = nil,
    foregroundColor: Color? = nil,
    borderColor: Color? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.variant = variant
    self.isInvalid = isInvalid
    self.backgroundColor = backgroundColor
    self.foregroundColor = foregroundColor
    self.borderColor = borderColor
    self.content = content()
  }

  public var body: some View {
    content.scBadge(
      variant,
      isInvalid: isInvalid,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor
    )
  }
}

extension SCBadge where Content == Text {
  public init(
    _ label: String,
    variant: SCBadgeVariant = .default,
    isInvalid: Bool = false,
    backgroundColor: Color? = nil,
    foregroundColor: Color? = nil,
    borderColor: Color? = nil
  ) {
    self.init(
      variant: variant,
      isInvalid: isInvalid,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor
    ) {
      Text(label)
    }
  }
}

// MARK: - Reusable chrome

/// Applies badge chrome while leaving interaction ownership with the receiver.
public struct SCBadgeModifier: ViewModifier {
  @Environment(\.theme) private var theme
  @Environment(\.isEnabled) private var isEnabled

  @State private var isHovered = false

  private let variant: SCBadgeVariant
  private let isInvalid: Bool
  private let backgroundColor: Color?
  private let foregroundColor: Color?
  private let borderColor: Color?

  public init(
    variant: SCBadgeVariant = .default,
    isInvalid: Bool = false,
    backgroundColor: Color? = nil,
    foregroundColor: Color? = nil,
    borderColor: Color? = nil
  ) {
    self.variant = variant
    self.isInvalid = isInvalid
    self.backgroundColor = backgroundColor
    self.foregroundColor = foregroundColor
    self.borderColor = borderColor
  }

  public func body(content: Content) -> some View {
    HStack(spacing: 4) {
      content
    }
    .font(.caption.weight(.medium))
    .lineLimit(1)
    .padding(.vertical, 3)
    .padding(.horizontal, 10)
    .background(resolvedBackground, in: Capsule())
    .overlay {
      if showsBorder {
        Capsule().strokeBorder(resolvedBorder)
      }
    }
    .foregroundStyle(resolvedForeground)
    .underline(variant == .link && isHovered)
    .contentShape(Capsule())
    .opacity(isEnabled ? 1 : 0.5)
    .shadow(
      color: isInvalid ? theme.destructive.opacity(0.22) : .clear,
      radius: isInvalid ? 3 : 0
    )
    .onHover { isHovered = $0 }
  }

  private var resolvedBackground: Color {
    if let backgroundColor { return backgroundColor }
    switch variant {
    case .default: return theme.primary.opacity(isHovered ? 0.9 : 1)
    case .secondary: return theme.secondary.opacity(isHovered ? 0.82 : 1)
    case .destructive: return theme.destructive.opacity(isHovered ? 0.9 : 1)
    case .outline, .ghost:
      return isHovered ? theme.accent : .clear
    case .link: return .clear
    }
  }

  private var resolvedForeground: Color {
    if let foregroundColor { return foregroundColor }
    switch variant {
    case .default: return theme.primaryForeground
    case .secondary: return theme.secondaryForeground
    case .destructive: return .white
    case .outline, .ghost: return theme.foreground
    case .link: return theme.primary
    }
  }

  private var showsBorder: Bool { variant == .outline || isInvalid || borderColor != nil }

  private var resolvedBorder: Color {
    if isInvalid { return theme.destructive }
    return borderColor ?? theme.border
  }
}

extension View {
  /// Styles this view as a badge without changing its native semantics.
  public func scBadge(
    _ variant: SCBadgeVariant = .default,
    isInvalid: Bool = false,
    backgroundColor: Color? = nil,
    foregroundColor: Color? = nil,
    borderColor: Color? = nil
  ) -> some View {
    modifier(
      SCBadgeModifier(
        variant: variant,
        isInvalid: isInvalid,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        borderColor: borderColor
      )
    )
  }
}

// MARK: - Native control style

/// Badge chrome for native buttons and links with real activation semantics.
public struct SCBadgeButtonStyle: ButtonStyle {
  private let variant: SCBadgeVariant
  private let isInvalid: Bool
  private let backgroundColor: Color?
  private let foregroundColor: Color?
  private let borderColor: Color?

  public init(
    variant: SCBadgeVariant = .default,
    isInvalid: Bool = false,
    backgroundColor: Color? = nil,
    foregroundColor: Color? = nil,
    borderColor: Color? = nil
  ) {
    self.variant = variant
    self.isInvalid = isInvalid
    self.backgroundColor = backgroundColor
    self.foregroundColor = foregroundColor
    self.borderColor = borderColor
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scBadge(
        variant,
        isInvalid: isInvalid,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        borderColor: borderColor
      )
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.78 : 1)
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == SCBadgeButtonStyle {
  public static func scBadge(
    _ variant: SCBadgeVariant = .default,
    isInvalid: Bool = false,
    backgroundColor: Color? = nil,
    foregroundColor: Color? = nil,
    borderColor: Color? = nil
  ) -> SCBadgeButtonStyle {
    SCBadgeButtonStyle(
      variant: variant,
      isInvalid: isInvalid,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor
    )
  }
}
