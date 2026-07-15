import SwiftUI

#if os(macOS)
  import AppKit
#endif

// MARK: - Trigger / Separator / Rail

/// An icon button that toggles the sidebar — put one in the detail pane's
/// top bar. On compact widths it presents the sheet; otherwise it
/// expands/collapses the pane.
public struct SCSidebarTrigger: View {
  @Environment(\.scSidebar) private var state

  public init() {}

  public var body: some View {
    Button(action: state.toggle) {
      Image(systemName: state.side == .leading ? "sidebar.leading" : "sidebar.trailing")
        .font(.system(size: 16, weight: .medium))
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
    .buttonStyle(.sc(.ghost, size: .iconSM))
    .accessibilityLabel("Toggle Sidebar")
    .scTooltip("Toggle sidebar", edge: .bottom)
    .help("Toggle Sidebar")
  }
}

/// A hairline divider for use inside the sidebar.
public struct SCSidebarSeparator: View {
  @Environment(\.theme) private var theme

  private let isDecorative: Bool
  private let accessibilityLabel: String

  public init(
    isDecorative: Bool = false,
    accessibilityLabel: String = "Separator"
  ) {
    self.isDecorative = isDecorative
    self.accessibilityLabel = accessibilityLabel
  }

  public var body: some View {
    SCSeparator(
      isDecorative: isDecorative,
      accessibilityLabel: accessibilityLabel
    )
    .environment(\.theme, separatorTheme)
    .padding(.horizontal, 12)
  }

  private var separatorTheme: Theme {
    var separatorTheme = theme
    separatorTheme.border = theme.sidebarBorder
    return separatorTheme
  }
}

/// An invisible 6pt strip along the sidebar's inner edge — tap or drag it
/// to toggle. `SCSidebarLayout` includes one automatically.
public struct SCSidebarRail: View {
  @Environment(\.scSidebar) private var state

  private let side: SCSidebarSide

  public init(side: SCSidebarSide = .leading) {
    self.side = side
  }

  public var body: some View {
    Color.clear
      .frame(width: 6)
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onEnded { value in
            let dx = value.translation.width
            if abs(dx) < 12 {
              state.toggle()
            } else {
              state.isOpen = side == .leading ? dx > 0 : dx < 0
            }
          }
      )
      .accessibilityLabel("Toggle Sidebar")
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { state.toggle() }
      .help("Toggle Sidebar")
      #if os(macOS)
        .onHover { isHovered in
          if isHovered {
            NSCursor.resizeLeftRight.push()
          } else {
            NSCursor.pop()
          }
        }
      #endif
  }
}
