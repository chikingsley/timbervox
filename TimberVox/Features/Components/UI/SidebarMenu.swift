// Depends on: Skeleton.swift
import SwiftUI

public enum SCSidebarMenuButtonVariant: CaseIterable, Hashable, Sendable {
  case `default`, outline
}

public enum SCSidebarMenuButtonSize: CaseIterable, Hashable, Sendable {
  case `default`, sm, lg

  fileprivate var height: CGFloat {
    switch self {
    case .default: 36
    case .sm: 32
    case .lg: 48
    }
  }
}

public enum SCSidebarMenuSubButtonSize: CaseIterable, Hashable, Sendable {
  case sm, md

  fileprivate var height: CGFloat {
    switch self {
    case .sm: 28
    case .md: 32
    }
  }
}

/// A single navigation row: icon + label + optional count pill. On the
/// icon rail it renders as a centered icon only.
///
///     SCSidebarMenuButton("Inbox", systemImage: "tray", badge: "3") { … }
public struct SCSidebarMenuButton: View {
  @Environment(\.theme) private var theme
  @Environment(\.scSidebarIconRail) private var iconRail

  private let isActive: Bool
  private let variant: SCSidebarMenuButtonVariant
  private let size: SCSidebarMenuButtonSize
  private let isDisabled: Bool
  private let accessibilityLabel: Text
  private let collapsedTooltip: String?
  private let action: () -> Void
  private let content: (Bool) -> AnyView
  private let trailing: (Bool) -> AnyView
  @State private var isHovered = false

  /// - Parameters:
  ///   - label: The row title (hidden on the icon rail).
  ///   - systemImage: Optional SF Symbol shown at the leading edge.
  ///   - isActive: Highlights the row with `theme.sidebarAccent`.
  ///   - badge: Optional trailing count pill (hidden on the icon rail).
  ///   - action: Runs on tap.
  public init(
    _ label: String,
    systemImage: String? = nil,
    isActive: Bool = false,
    variant: SCSidebarMenuButtonVariant = .default,
    size: SCSidebarMenuButtonSize = .default,
    isDisabled: Bool = false,
    badge: String? = nil,
    action: @escaping () -> Void
  ) {
    self.isActive = isActive
    self.variant = variant
    self.size = size
    self.isDisabled = isDisabled
    self.accessibilityLabel = Text(label)
    self.collapsedTooltip = label
    self.action = action
    self.content = { collapsed in
      AnyView(
        HStack(spacing: 8) {
          if let systemImage {
            Image(systemName: systemImage)
              .font(.system(size: 16, weight: .medium))
              .frame(width: 20, height: 20)
          }
          if !collapsed {
            Text(label)
              .font(.subheadline.weight(.medium))
              .lineLimit(1)
          }
        }
      )
    }
    self.trailing = { collapsed in
      AnyView(
        Group {
          if let badge, !collapsed {
            SCSidebarMenuBadge { Text(badge) }
          }
        }
      )
    }
  }

  /// Creates a fully custom menu button. Builders receive the icon-rail
  /// state so custom labels can decide what remains visible when collapsed.
  public init<Content: View, Trailing: View>(
    isActive: Bool = false,
    variant: SCSidebarMenuButtonVariant = .default,
    size: SCSidebarMenuButtonSize = .default,
    isDisabled: Bool = false,
    accessibilityLabel: Text,
    collapsedTooltip: String? = nil,
    action: @escaping () -> Void,
    @ViewBuilder content: @escaping (_ collapsed: Bool) -> Content,
    @ViewBuilder trailing: @escaping (_ collapsed: Bool) -> Trailing
  ) {
    self.isActive = isActive
    self.variant = variant
    self.size = size
    self.isDisabled = isDisabled
    self.accessibilityLabel = accessibilityLabel
    self.collapsedTooltip = collapsedTooltip
    self.action = action
    self.content = { AnyView(content($0)) }
    self.trailing = { AnyView(trailing($0)) }
  }

  /// Creates a fully custom menu button without trailing content.
  public init<Content: View>(
    isActive: Bool = false,
    variant: SCSidebarMenuButtonVariant = .default,
    size: SCSidebarMenuButtonSize = .default,
    isDisabled: Bool = false,
    accessibilityLabel: Text,
    collapsedTooltip: String? = nil,
    action: @escaping () -> Void,
    @ViewBuilder content: @escaping (_ collapsed: Bool) -> Content
  ) {
    self.init(
      isActive: isActive,
      variant: variant,
      size: size,
      isDisabled: isDisabled,
      accessibilityLabel: accessibilityLabel,
      collapsedTooltip: collapsedTooltip,
      action: action,
      content: content
    ) { _ in EmptyView() }
  }

  @ViewBuilder
  public var body: some View {
    if iconRail, let collapsedTooltip {
      button.scTooltip(collapsedTooltip, edge: .trailing)
    } else {
      button
    }
  }

  private var button: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        content(iconRail)
        if !iconRail {
          Spacer(minLength: 0)
          trailing(iconRail)
        }
      }
      .transition(.opacity)
      .padding(.horizontal, iconRail ? 0 : 10)
      .frame(maxWidth: .infinity, alignment: iconRail ? .center : .leading)
      .frame(height: size.height)
      .contentShape(RoundedRectangle(cornerRadius: theme.radius - 2, style: .continuous))
    }
    .frame(maxWidth: .infinity)
    .buttonStyle(
      SCSidebarMenuButtonStyle(
        isActive: isActive,
        isHovered: isHovered,
        variant: variant
      )
    )
    .disabled(isDisabled)
    .onHover { isHovered = $0 }
    .animation(SCSidebarMetrics.animation, value: iconRail)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(isActive ? .isSelected : [])
  }
}

private struct SCSidebarMenuButtonStyle: ButtonStyle {
  @Environment(\.theme) private var theme
  @Environment(\.isEnabled) private var isEnabled
  let isActive: Bool
  let isHovered: Bool
  let variant: SCSidebarMenuButtonVariant

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        background(pressed: configuration.isPressed),
        in: RoundedRectangle(cornerRadius: theme.radius - 2, style: .continuous)
      )
      .foregroundStyle(isActive ? theme.sidebarAccentForeground : theme.sidebarForeground)
      .overlay {
        if variant == .outline {
          RoundedRectangle(cornerRadius: theme.radius - 2, style: .continuous)
            .strokeBorder(theme.sidebarBorder)
        }
      }
      .opacity(isEnabled ? 1 : 0.5)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }

  private func background(pressed: Bool) -> Color {
    if isActive { return theme.sidebarAccent }
    if pressed { return theme.sidebarAccent.opacity(0.8) }
    return isHovered ? theme.sidebarAccent.opacity(0.7) : .clear
  }
}

/// Visual treatment for a nested sidebar menu.
public enum SCSidebarMenuSubStyle: Hashable, Sendable {
  /// The standard inset treatment with a leading guide line.
  case indented
  /// A compact inset without a guide line, used by floating sidebars.
  case flush
}

/// A nested sidebar menu. Hidden entirely on the icon rail.
public struct SCSidebarMenuSub<Content: View>: View {
  @Environment(\.theme) private var theme
  @Environment(\.scSidebarIconRail) private var iconRail

  private let style: SCSidebarMenuSubStyle
  private let content: Content

  public init(
    style: SCSidebarMenuSubStyle = .indented,
    @ViewBuilder content: () -> Content
  ) {
    self.style = style
    self.content = content()
  }

  public var body: some View {
    if !iconRail {
      VStack(alignment: .leading, spacing: 2) {
        content
      }
      .padding(.leading, style == .indented ? 28 : 6)
      .padding(.trailing, style == .flush ? 6 : 0)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(alignment: .leading) {
        if style == .indented {
          Rectangle()
            .fill(theme.sidebarBorder)
            .frame(width: 1)
            .padding(.leading, 18)
            .padding(.vertical, 4)
        }
      }
      .transition(.opacity)
    }
  }
}

/// A semantic container for one nested menu row.
public struct SCSidebarMenuSubItem<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content.frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A nested navigation button with arbitrary content.
public struct SCSidebarMenuSubButton<Content: View>: View {
  @Environment(\.theme) private var theme

  private let isActive: Bool
  private let size: SCSidebarMenuSubButtonSize
  private let isDisabled: Bool
  private let accessibilityLabel: Text
  private let action: () -> Void
  private let content: Content

  public init(
    isActive: Bool = false,
    size: SCSidebarMenuSubButtonSize = .md,
    isDisabled: Bool = false,
    accessibilityLabel: Text,
    action: @escaping () -> Void,
    @ViewBuilder content: () -> Content
  ) {
    self.isActive = isActive
    self.size = size
    self.isDisabled = isDisabled
    self.accessibilityLabel = accessibilityLabel
    self.action = action
    self.content = content()
  }

  public var body: some View {
    Button(action: action) {
      content
        .font(size == .sm ? .caption : .footnote)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .frame(height: size.height)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .foregroundStyle(isActive ? theme.sidebarAccentForeground : theme.sidebarForeground)
    .background(
      isActive ? theme.sidebarAccent : .clear,
      in: RoundedRectangle(cornerRadius: max(theme.radius - 3, 3), style: .continuous)
    )
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(isActive ? .isSelected : [])
    .opacity(isDisabled ? 0.5 : 1)
  }
}

extension SCSidebarMenuSubButton where Content == Text {
  public init(
    _ label: String,
    isActive: Bool = false,
    size: SCSidebarMenuSubButtonSize = .md,
    isDisabled: Bool = false,
    action: @escaping () -> Void
  ) {
    self.init(
      isActive: isActive,
      size: size,
      isDisabled: isDisabled,
      accessibilityLabel: Text(label),
      action: action
    ) {
      Text(label)
    }
  }
}
