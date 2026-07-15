import SwiftUI

// MARK: - Header / Content / Footer

/// The sidebar's top slot — app identity, workspace switcher, search.
public struct SCSidebarHeader<Content: View>: View {
  @Environment(\.scSidebarIconRail) private var iconRail
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: iconRail ? .center : .leading, spacing: 8) {
      content
    }
    .frame(maxWidth: .infinity, alignment: iconRail ? .center : .leading)
    .padding(12)
  }
}

/// The sidebar's scrollable middle slot — holds `SCSidebarGroup`s.
public struct SCSidebarContent<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          content
        }
        .frame(
          maxWidth: .infinity,
          minHeight: geometry.size.height,
          alignment: .topLeading
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// The sidebar's bottom slot — user row, sign-out, version.
public struct SCSidebarFooter<Content: View>: View {
  @Environment(\.scSidebarIconRail) private var iconRail
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: iconRail ? .center : .leading, spacing: 8) {
      content
    }
    .frame(maxWidth: .infinity, alignment: iconRail ? .center : .leading)
    .padding(12)
  }
}

// MARK: - Group / Menu

/// A labeled section inside `SCSidebarContent`. The label hides on the
/// icon rail.
public struct SCSidebarGroup<Content: View>: View {
  @Environment(\.theme) private var theme
  @Environment(\.scSidebarIconRail) private var iconRail

  private let label: String?
  private let content: Content

  public init(_ label: String? = nil, @ViewBuilder content: () -> Content) {
    self.label = label
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let label, !iconRail {
        Text(label)
          .font(.caption.weight(.medium))
          .foregroundStyle(theme.sidebarForeground.opacity(0.6))
          .lineLimit(1)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .transition(.opacity)
      }
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
  }
}

/// A composable group heading. It hides automatically in the icon rail.
public struct SCSidebarGroupLabel<Content: View>: View {
  @Environment(\.theme) private var theme
  @Environment(\.scSidebarIconRail) private var iconRail

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    if !iconRail {
      content
        .font(.caption.weight(.medium))
        .foregroundStyle(theme.sidebarForeground.opacity(0.6))
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// A trailing action for a sidebar group header.
public struct SCSidebarGroupAction<Content: View>: View {
  @Environment(\.theme) private var theme
  @Environment(\.scSidebarIconRail) private var iconRail

  private let accessibilityLabel: Text
  private let isDisabled: Bool
  private let action: () -> Void
  private let content: Content

  public init(
    accessibilityLabel: Text,
    isDisabled: Bool = false,
    action: @escaping () -> Void,
    @ViewBuilder content: () -> Content
  ) {
    self.accessibilityLabel = accessibilityLabel
    self.isDisabled = isDisabled
    self.action = action
    self.content = content()
  }

  public var body: some View {
    if !iconRail {
      Button(action: action) {
        content
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(isDisabled)
      .foregroundStyle(theme.sidebarForeground)
      .accessibilityLabel(accessibilityLabel)
      .opacity(isDisabled ? 0.5 : 1)
    }
  }
}

/// The body region of a sidebar group. Kept separate so labels and actions
/// can be freely arranged without making `SCSidebarGroup` opinionated.
public struct SCSidebarGroupContent<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content.frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Shows arbitrary sidebar content only while the sidebar is expanded.
/// Use it for groups such as sidebar-07's Projects section, which shadcn
/// intentionally removes from the icon rail instead of reducing to icons.
public struct SCSidebarExpandedOnly<Content: View>: View {
  @Environment(\.scSidebarIconRail) private var iconRail
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    if !iconRail { content }
  }
}

/// A vertical stack of `SCSidebarMenuButton`s.
public struct SCSidebarMenu<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 8)
  }
}

/// A positioning container for a menu row and optional trailing actions.
public struct SCSidebarMenuItem<Content: View>: View {
  @State private var isHovered = false
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    ZStack(alignment: .trailing) { content }
      .frame(maxWidth: .infinity, alignment: .leading)
      .environment(\.scSidebarMenuItemHovered, isHovered)
      .onHover { isHovered = $0 }
  }
}

private struct SCSidebarMenuItemHoveredKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  fileprivate var scSidebarMenuItemHovered: Bool {
    get { self[SCSidebarMenuItemHoveredKey.self] }
    set { self[SCSidebarMenuItemHoveredKey.self] = newValue }
  }
}

/// A compact action intended for the trailing edge of a menu item.
public struct SCSidebarMenuAction<Content: View>: View {
  @Environment(\.theme) private var theme
  @Environment(\.scSidebarIconRail) private var iconRail
  @Environment(\.scSidebarMenuItemHovered) private var menuItemHovered
  @FocusState private var isFocused: Bool

  private let accessibilityLabel: Text
  private let showOnHover: Bool
  private let isDisabled: Bool
  private let action: () -> Void
  private let content: Content

  public init(
    accessibilityLabel: Text,
    showOnHover: Bool = false,
    isDisabled: Bool = false,
    action: @escaping () -> Void,
    @ViewBuilder content: () -> Content
  ) {
    self.accessibilityLabel = accessibilityLabel
    self.showOnHover = showOnHover
    self.isDisabled = isDisabled
    self.action = action
    self.content = content()
  }

  public var body: some View {
    if !iconRail {
      Button(action: action) {
        content
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(isDisabled)
      .focused($isFocused)
      .foregroundStyle(theme.sidebarForeground.opacity(0.7))
      .accessibilityLabel(accessibilityLabel)
      .padding(.trailing, 4)
      .opacity(isActionVisible ? (isDisabled ? 0.5 : 1) : 0)
      .allowsHitTesting(isActionVisible)
      .animation(.easeOut(duration: 0.12), value: isActionVisible)
    }
  }

  private var isActionVisible: Bool {
    !showOnHover || menuItemHovered || isFocused
  }
}

/// Arbitrary trailing badge content for a menu row.
public struct SCSidebarMenuBadge<Content: View>: View {
  @Environment(\.theme) private var theme
  @Environment(\.scSidebarIconRail) private var iconRail

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    if !iconRail {
      content
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(theme.sidebarPrimaryForeground)
        .background(theme.sidebarPrimary, in: Capsule())
    }
  }
}
