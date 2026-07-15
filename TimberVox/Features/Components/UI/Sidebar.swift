// ============================================================
// Sidebar.swift — swiftcn-ui
// Depends on: Theme/ · Sheet.swift
//
// SwiftUI port of shadcn/ui's Sidebar — a composable, collapsible
// app sidebar. The family is split across Sidebar*.swift files while
// preserving shadcn's single composable primitive set:
//
//     SCSidebarLayout(collapsible: .icon) {
//         SCSidebarHeader { … }
//         SCSidebarContent {
//             SCSidebarGroup("Platform") {
//                 SCSidebarMenu {
//                     SCSidebarMenuButton("Home", systemImage: "house") { … }
//                 }
//             }
//         }
//         SCSidebarFooter { … }
//     } detail: {
//         …  // put an SCSidebarTrigger() in your top bar
//     }
// ============================================================
import SwiftUI

// MARK: - Layout

/// The sidebar shell: a sidebar pane plus your main content, with collapse
/// animation, ⌘B toggling, `@AppStorage` persistence, and an automatic
/// sheet fallback on compact widths (iPhone).
///
///     SCSidebarLayout(collapsible: .icon, side: .leading) {
///         SCSidebarHeader { … }
///         SCSidebarContent { … }
///         SCSidebarFooter { … }
///     } detail: {
///         …
///     }
public struct SCSidebarLayout<SidebarContent: View, Detail: View>: View {
  @Environment(\.theme) private var theme
  #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  @State private var state: SCSidebarState

  private let collapsible: SCSidebarCollapsible
  private let side: SCSidebarSide
  private let variant: SCSidebarVariant
  private let persistenceKey: String?
  private let expandedWidth: CGFloat
  private let collapsedWidth: CGFloat
  private let compactWidth: CGFloat
  private let showsDivider: Bool
  private let onOpenChange: ((Bool) -> Void)?
  private let sidebar: SidebarContent
  private let detail: Detail

  /// - Parameters:
  ///   - collapsible: How the sidebar collapses (default `.offcanvas`).
  ///   - side: Which edge the sidebar occupies (default `.leading`).
  ///   - persistenceKey: `UserDefaults` key under which the open state is
  ///     restored across launches (mirrors shadcn's cookie). Give each
  ///     distinct sidebar its own key; pass `nil` to disable persistence
  ///     (embedded demos, previews).
  ///   - sidebar: Sidebar content — compose `SCSidebarHeader`,
  ///     `SCSidebarContent`, and `SCSidebarFooter`.
  ///   - detail: The main content pane.
  public init(
    collapsible: SCSidebarCollapsible = .offcanvas,
    side: SCSidebarSide = .leading,
    variant: SCSidebarVariant = .sidebar,
    persistenceKey: String? = "sc.sidebar.open",
    expandedWidth: CGFloat = 272,
    collapsedWidth: CGFloat = 56,
    compactWidth: CGFloat = 288,
    showsDivider: Bool = true,
    state externalState: SCSidebarState? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    @ViewBuilder sidebar: () -> SidebarContent,
    @ViewBuilder detail: () -> Detail
  ) {
    self.collapsible = collapsible
    self.side = side
    self.variant = variant
    self.persistenceKey = persistenceKey
    self.expandedWidth = max(expandedWidth, 160)
    self.collapsedWidth = max(collapsedWidth, 44)
    self.compactWidth = max(compactWidth, 160)
    self.showsDivider = showsDivider
    self.onOpenChange = onOpenChange
    self.sidebar = sidebar()
    self.detail = detail()
    let initialState: SCSidebarState
    if let externalState {
      initialState = externalState
      initialState.collapsible = collapsible
      initialState.side = side
    } else {
      let restored =
        persistenceKey.flatMap {
          UserDefaults.standard.object(forKey: $0) as? Bool
        } ?? true
      initialState = SCSidebarState(
        isOpen: restored,
        collapsible: collapsible,
        side: side
      )
    }
    _state = State(initialValue: initialState)
  }

  public var body: some View {
    Group {
      if isCompact {
        compactLayout
      } else {
        regularLayout
      }
    }
    .background(keyboardToggle)
    .environment(\.scSidebar, state)
    .onAppear {
      state.collapsible = collapsible
      state.isCompact = isCompact
      state.side = side
    }
    .onChange(of: state.isOpen) { _, newValue in
      if let persistenceKey {
        UserDefaults.standard.set(newValue, forKey: persistenceKey)
      }
      onOpenChange?(newValue)
    }
    .onChange(of: collapsible) { _, newValue in
      state.collapsible = newValue
    }
    .onChange(of: side) { _, newValue in
      state.side = newValue
    }
    .onChange(of: isCompact) { _, newValue in
      state.isCompact = newValue
      state.openMobile = false
    }
  }

  // MARK: Regular width (iPad / Mac)

  private var regularLayout: some View {
    HStack(spacing: 0) {
      if side == .leading {
        pane
        if variant == .sidebar, showsDivider { divider }
      }
      detailContainer
      if side == .trailing {
        if variant == .sidebar, showsDivider { divider }
        pane
      }
    }
    .overlay(alignment: side == .leading ? .leading : .trailing) {
      if collapsible != .none {
        SCSidebarRail(side: side)
          .padding(
            side == .leading ? .leading : .trailing,
            max(paneWidth - 3, 0)
          )
      }
    }
    .animation(SCSidebarMetrics.animation, value: state.isOpen)
    .padding(variant == .floating ? 8 : 0)
    .background(variant == .inset ? theme.sidebar : theme.background)
  }

  private var pane: some View {
    sidebarStack
      .environment(\.scSidebarIconRail, isIconRail)
      .foregroundStyle(theme.sidebarForeground)
      .frame(maxHeight: .infinity)
      .frame(width: contentWidth)
      .frame(width: paneWidth, alignment: side == .leading ? .trailing : .leading)
      .clipped()
      .background(theme.sidebar, in: paneShape)
      .overlay {
        if variant != .sidebar {
          paneShape.strokeBorder(theme.sidebarBorder)
        }
      }
  }

  private var divider: some View {
    Rectangle()
      .fill(theme.sidebarBorder)
      .frame(width: 1)
      .ignoresSafeArea()
  }

  @ViewBuilder
  private var detailContainer: some View {
    if variant == .inset {
      detail
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background, in: paneShape)
        .clipShape(paneShape)
        .overlay { paneShape.strokeBorder(theme.border) }
        .padding(8)
    } else {
      detail.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var paneShape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: variant == .sidebar ? 0 : theme.radius + 4,
      style: .continuous
    )
  }

  private var isIconRail: Bool {
    collapsible == .icon && !state.isOpen
  }

  /// The width the sidebar's children lay out at.
  private var contentWidth: CGFloat {
    isIconRail ? collapsedWidth : expandedWidth
  }

  /// The width the pane actually occupies in the HStack.
  private var paneWidth: CGFloat {
    guard collapsible != .none, !state.isOpen else {
      return expandedWidth
    }
    return collapsible == .icon ? collapsedWidth : 0
  }

  // MARK: Compact width (iPad split view / narrow iOS container)

  private var compactLayout: some View {
    @Bindable var sidebarState = state
    return
      detailContainer
      .background(theme.background)
      .scSheet(
        isPresented: $sidebarState.openMobile,
        edge: side == .leading ? .leading : .trailing,
        panelSize: compactWidth,
        maximumPanelSize: compactWidth
      ) {
        SCSheetContent(showsCloseButton: false, spacing: 0, padding: 0) {
          sidebarStack
            .environment(\.scSidebarIconRail, false)
            .foregroundStyle(theme.sidebarForeground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.sidebar)
            .accessibilityLabel("Sidebar")
            .accessibilityHint("Displays the application navigation sidebar")
        }
        .background(theme.sidebar)
      }
  }

  // MARK: Shared

  private var sidebarStack: some View {
    VStack(spacing: 0) { sidebar }
  }

  /// Hidden buttons that bind Command-B and Control-B to the shared toggle.
  private var keyboardToggle: some View {
    Group {
      Button("") { state.toggle() }
        .keyboardShortcut("b", modifiers: .command)
        .buttonStyle(.plain)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)

      Button("") { state.toggle() }
        .keyboardShortcut("b", modifiers: .control)
        .buttonStyle(.plain)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
  }

  private var isCompact: Bool {
    #if os(iOS)
      return horizontalSizeClass == .compact
    #else
      return false
    #endif
  }
}
