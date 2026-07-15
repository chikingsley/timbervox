// ============================================================
// Sheet.swift — swiftcn-ui
// Depends on: Drawer.swift · Button.swift · Theme/
// ============================================================
import SwiftUI

// MARK: - Edge

/// The semantic container edge from which a Sheet appears.
public enum SCSheetEdge: CaseIterable, Equatable, Hashable, Sendable {
  case top
  case bottom
  case leading
  case trailing

  var isHorizontal: Bool {
    self == .leading || self == .trailing
  }

  var drawerDirection: SCDrawerSwipeDirection {
    switch self {
    case .top: .up
    case .bottom: .down
    case .leading: .left
    case .trailing: .right
    }
  }

  /// The panel side facing the underlying content.
  var borderAlignment: Alignment {
    switch self {
    case .top: .bottom
    case .bottom: .top
    case .leading: .trailing
    case .trailing: .leading
    }
  }
}

// MARK: - Compatibility dismissal environment

/// A concurrency-safe command for dismissing the nearest Swiftcn Sheet.
public struct SCDismissSheetAction: Sendable {
  private let action: @MainActor @Sendable () -> Void

  public init(_ action: @escaping @MainActor @Sendable () -> Void = {}) {
    self.action = action
  }

  @MainActor public func callAsFunction() {
    action()
  }
}

private struct SCDismissSheetKey: EnvironmentKey {
  static let defaultValue = SCDismissSheetAction()
}

private struct SCSheetEdgeKey: EnvironmentKey {
  static let defaultValue: SCSheetEdge = .trailing
}

extension EnvironmentValues {
  /// Dismisses the nearest enclosing `SCSheet` or `.scSheet` presentation.
  public var scDismissSheet: SCDismissSheetAction {
    get { self[SCDismissSheetKey.self] }
    set { self[SCDismissSheetKey.self] = newValue }
  }

  var scSheetEdge: SCSheetEdge {
    get { self[SCSheetEdgeKey.self] }
    set { self[SCSheetEdgeKey.self] = newValue }
  }
}

// MARK: - Root

/// A controlled or internally managed composable Sheet.
///
/// Sheet deliberately reuses the Drawer presentation engine with dragging and
/// snap points disabled. This gives Root, Trigger, Overlay, Content, and Close
/// one source of truth for focus restoration, Escape, scrim dismissal, inert
/// background content, reduced motion, modal accessibility, and all four edges.
public struct SCSheet<Trigger: View, SheetContent: View, Overlay: View>: View {
  private let externalIsPresented: Binding<Bool>?
  private let defaultPresented: Bool
  private let edge: SCSheetEdge
  private let dismissOnScrimTap: Bool
  private let dismissOnEscape: Bool
  private let panelSize: CGFloat?
  private let maximumPanelSize: CGFloat?
  private let onOpenChange: ((Bool) -> Void)?
  private let trigger: Trigger
  private let overlay: Overlay
  private let sheetContent: SheetContent

  public init(
    isPresented: Binding<Bool>,
    edge: SCSheetEdge = .trailing,
    dismissOnScrimTap: Bool = true,
    dismissOnEscape: Bool = true,
    panelSize: CGFloat? = nil,
    maximumPanelSize: CGFloat? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder overlay: () -> Overlay,
    @ViewBuilder content: () -> SheetContent
  ) {
    self.externalIsPresented = isPresented
    self.defaultPresented = isPresented.wrappedValue
    self.edge = edge
    self.dismissOnScrimTap = dismissOnScrimTap
    self.dismissOnEscape = dismissOnEscape
    self.panelSize = panelSize.map { max($0, 80) }
    self.maximumPanelSize = maximumPanelSize.map { max($0, 80) }
    self.onOpenChange = onOpenChange
    self.trigger = trigger()
    self.overlay = overlay()
    self.sheetContent = content()
  }

  public init(
    defaultPresented: Bool = false,
    edge: SCSheetEdge = .trailing,
    dismissOnScrimTap: Bool = true,
    dismissOnEscape: Bool = true,
    panelSize: CGFloat? = nil,
    maximumPanelSize: CGFloat? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder overlay: () -> Overlay,
    @ViewBuilder content: () -> SheetContent
  ) {
    self.externalIsPresented = nil
    self.defaultPresented = defaultPresented
    self.edge = edge
    self.dismissOnScrimTap = dismissOnScrimTap
    self.dismissOnEscape = dismissOnEscape
    self.panelSize = panelSize.map { max($0, 80) }
    self.maximumPanelSize = maximumPanelSize.map { max($0, 80) }
    self.onOpenChange = onOpenChange
    self.trigger = trigger()
    self.overlay = overlay()
    self.sheetContent = content()
  }

  @ViewBuilder
  public var body: some View {
    if let externalIsPresented {
      SCDrawer(
        isPresented: externalIsPresented,
        modalBehavior: .modal,
        showSwipeHandle: false,
        swipeDirection: edge.drawerDirection,
        swipeEnabled: false,
        disablePointerDismissal: !dismissOnScrimTap,
        dismissOnEscape: dismissOnEscape,
        panelSize: panelSize,
        maximumPanelSize: maximumPanelSize,
        onOpenChange: onOpenChange,
        trigger: { trigger },
        overlay: { overlay },
        content: {
          SCSheetEnvironmentBridge(edge: edge) {
            sheetContent
          }
        }
      )
    } else {
      SCDrawer(
        defaultPresented: defaultPresented,
        modalBehavior: .modal,
        showSwipeHandle: false,
        swipeDirection: edge.drawerDirection,
        swipeEnabled: false,
        disablePointerDismissal: !dismissOnScrimTap,
        dismissOnEscape: dismissOnEscape,
        panelSize: panelSize,
        maximumPanelSize: maximumPanelSize,
        onOpenChange: onOpenChange,
        trigger: { trigger },
        overlay: { overlay },
        content: {
          SCSheetEnvironmentBridge(edge: edge) {
            sheetContent
          }
        }
      )
    }
  }
}

extension SCSheet where Overlay == SCSheetOverlay {
  public init(
    isPresented: Binding<Bool>,
    edge: SCSheetEdge = .trailing,
    dismissOnScrimTap: Bool = true,
    dismissOnEscape: Bool = true,
    panelSize: CGFloat? = nil,
    maximumPanelSize: CGFloat? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder content: () -> SheetContent
  ) {
    self.init(
      isPresented: isPresented,
      edge: edge,
      dismissOnScrimTap: dismissOnScrimTap,
      dismissOnEscape: dismissOnEscape,
      panelSize: panelSize,
      maximumPanelSize: maximumPanelSize,
      onOpenChange: onOpenChange,
      trigger: trigger,
      overlay: { SCSheetOverlay() },
      content: content
    )
  }

  public init(
    defaultPresented: Bool = false,
    edge: SCSheetEdge = .trailing,
    dismissOnScrimTap: Bool = true,
    dismissOnEscape: Bool = true,
    panelSize: CGFloat? = nil,
    maximumPanelSize: CGFloat? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder content: () -> SheetContent
  ) {
    self.init(
      defaultPresented: defaultPresented,
      edge: edge,
      dismissOnScrimTap: dismissOnScrimTap,
      dismissOnEscape: dismissOnEscape,
      panelSize: panelSize,
      maximumPanelSize: maximumPanelSize,
      onOpenChange: onOpenChange,
      trigger: trigger,
      overlay: { SCSheetOverlay() },
      content: content
    )
  }
}
