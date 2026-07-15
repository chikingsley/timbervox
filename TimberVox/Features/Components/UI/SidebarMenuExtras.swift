// ============================================================
// SidebarMenuExtras.swift — swiftcn-ui
// Supplemental source for: sidebar
// ============================================================
import SwiftUI

/// A loading placeholder matching a sidebar menu row.
public struct SCSidebarMenuSkeleton: View {
  @Environment(\.theme) private var theme
  @Environment(\.scSidebarIconRail) private var iconRail

  private let showsIcon: Bool

  public init(showsIcon: Bool = false) {
    self.showsIcon = showsIcon
  }

  public var body: some View {
    HStack(spacing: 8) {
      if showsIcon {
        SCSkeleton(width: 20, height: 20)
          .environment(\.theme, skeletonTheme)
      }
      if !iconRail {
        SCSkeleton(width: 112, height: 12)
          .environment(\.theme, skeletonTheme)
      }
    }
    .frame(maxWidth: .infinity, alignment: iconRail ? .center : .leading)
    .frame(height: 36)
    .padding(.horizontal, iconRail ? 0 : 10)
    .accessibilityHidden(true)
  }

  private var skeletonTheme: Theme {
    var skeletonTheme = theme
    skeletonTheme.background = theme.sidebar
    skeletonTheme.muted = theme.sidebarAccent
    return skeletonTheme
  }
}

/// A search or filter field styled for the sidebar token family.
public struct SCSidebarInput: View {
  @Environment(\.theme) private var theme
  @Environment(\.scSidebarIconRail) private var iconRail

  private let placeholder: String
  private let icon: String?
  private let onSubmit: (() -> Void)?
  @Binding private var text: String

  public init(
    _ placeholder: String = "Search",
    text: Binding<String>,
    icon: String? = nil,
    onSubmit: (() -> Void)? = nil
  ) {
    self.placeholder = placeholder
    self._text = text
    self.icon = icon
    self.onSubmit = onSubmit
  }

  public var body: some View {
    if !iconRail {
      SCInput(
        placeholder,
        text: $text,
        icon: icon,
        kind: .search,
        size: .sm,
        onSubmit: onSubmit
      )
      .environment(\.theme, inputTheme)
    }
  }

  private var inputTheme: Theme {
    var inputTheme = theme
    inputTheme.background = theme.sidebar
    inputTheme.foreground = theme.sidebarForeground
    inputTheme.input = theme.sidebarBorder
    inputTheme.ring = theme.sidebarRing
    inputTheme.mutedForeground = theme.sidebarForeground.opacity(0.6)
    return inputTheme
  }
}

/// A reusable detail surface for custom sidebar compositions.
public struct SCSidebarInset<Content: View>: View {
  @Environment(\.theme) private var theme

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(theme.background, in: shape)
      .clipShape(shape)
      .overlay { shape.strokeBorder(theme.border) }
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: theme.radius + 4, style: .continuous)
  }
}
