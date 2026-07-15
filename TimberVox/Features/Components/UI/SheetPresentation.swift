// ============================================================
// SheetPresentation.swift — swiftcn-ui
// Supplemental source for: sheet
// ============================================================
import SwiftUI

// MARK: - Modifier convenience

extension View {
  /// Presents caller-controlled Sheet content over this container using the
  /// same Drawer-backed engine as `SCSheet`.
  public func scSheet<SheetContent: View>(
    isPresented: Binding<Bool>,
    edge: SCSheetEdge = .trailing,
    dismissOnScrimTap: Bool = true,
    dismissOnEscape: Bool = true,
    panelSize: CGFloat? = nil,
    maximumPanelSize: CGFloat? = nil,
    onOpenChange: ((Bool) -> Void)? = nil,
    @ViewBuilder content: @escaping () -> SheetContent
  ) -> some View {
    scDrawer(
      isPresented: isPresented,
      modalBehavior: .modal,
      showSwipeHandle: false,
      swipeDirection: edge.drawerDirection,
      swipeEnabled: false,
      disablePointerDismissal: !dismissOnScrimTap,
      dismissOnEscape: dismissOnEscape,
      panelSize: panelSize,
      maximumPanelSize: maximumPanelSize,
      onOpenChange: onOpenChange
    ) {
      SCSheetEnvironmentBridge(edge: edge, content: content)
    }
  }
}

struct SCSheetEnvironmentBridge<Content: View>: View {
  @Environment(\.scDismissDrawer) private var dismissDrawer

  let edge: SCSheetEdge
  let content: Content

  init(
    edge: SCSheetEdge,
    @ViewBuilder content: () -> Content
  ) {
    self.edge = edge
    self.content = content()
  }

  var body: some View {
    content
      .environment(\.scSheetEdge, edge)
      .environment(
        \.scDismissSheet,
        SCDismissSheetAction { dismissDrawer() }
      )
  }
}

// MARK: - Trigger, overlay, and close

/// Opens the enclosing Sheet and restores focus to itself after dismissal.
public struct SCSheetTrigger<Label: View>: View {
  private let label: Label

  public init(@ViewBuilder label: () -> Label) {
    self.label = label()
  }

  public var body: some View {
    SCDrawerTrigger {
      label
    }
  }
}

extension SCSheetTrigger where Label == Text {
  public init(_ title: String) {
    self.init { Text(title) }
  }
}

/// The Sheet's real modal scrim.
public struct SCSheetOverlay: View {
  private let opacity: Double

  public init(opacity: Double = 0.5) {
    self.opacity = min(max(opacity, 0), 1)
  }

  public var body: some View {
    SCDrawerOverlay(opacity: opacity)
  }
}

/// Dismisses the enclosing Sheet and optionally runs a caller action.
public struct SCSheetClose<Label: View>: View {
  private let action: () -> Void
  private let label: Label

  public init(
    action: @escaping () -> Void = {},
    @ViewBuilder label: () -> Label
  ) {
    self.action = action
    self.label = label()
  }

  public var body: some View {
    SCDrawerClose(action: action) {
      label
    }
  }
}

extension SCSheetClose where Label == Text {
  public init(_ title: String = "Close", action: @escaping () -> Void = {}) {
    self.init(action: action) { Text(title) }
  }
}

// MARK: - Content

/// The edge-pinned Sheet surface. Include an `SCSheetTitle` in every Sheet so
/// assistive technologies receive a meaningful modal heading.
public struct SCSheetContent<Content: View>: View {
  @Environment(\.theme) private var theme
  @Environment(\.scSheetEdge) private var edge
  @FocusState private var isFocused: Bool

  private let showsCloseButton: Bool
  private let spacing: CGFloat
  private let padding: CGFloat
  private let content: Content

  public init(
    showsCloseButton: Bool = true,
    spacing: CGFloat = 16,
    padding: CGFloat = 24,
    @ViewBuilder content: () -> Content
  ) {
    self.showsCloseButton = showsCloseButton
    self.spacing = max(spacing, 0)
    self.padding = max(padding, 0)
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: spacing) {
      content
    }
    .padding(padding)
    .frame(
      maxWidth: .infinity,
      maxHeight: edge.isHorizontal ? .infinity : nil,
      alignment: .topLeading
    )
    .background(theme.background)
    .overlay(alignment: edge.borderAlignment) {
      Rectangle()
        .fill(theme.border)
        .frame(
          width: edge.isHorizontal ? 1 : nil,
          height: edge.isHorizontal ? nil : 1
        )
        .accessibilityHidden(true)
    }
    .overlay(alignment: .topTrailing) {
      if showsCloseButton {
        SCSheetClose {
          Image(systemName: "xmark")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.mutedForeground)
        }
        .buttonStyle(.sc(.ghost, size: .iconSM))
        .padding(8)
        .accessibilityLabel("Close")
      }
    }
    .foregroundStyle(theme.foreground)
    .accessibilityElement(children: .contain)
    .focusable()
    .focused($isFocused)
    .onAppear { isFocused = true }
  }
}
