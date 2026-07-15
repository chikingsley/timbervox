// ============================================================
// HoverCard.swift — swiftcn-ui
// Depends on: Theme/
// ============================================================
import SwiftUI

// MARK: - Configuration

public enum SCHoverCardSide: Hashable, Sendable {
  case top
  case bottom
  /// Logical inline-start placement.
  case leading
  /// Logical inline-end placement.
  case trailing
  /// Physical left placement regardless of layout direction.
  case left
  /// Physical right placement regardless of layout direction.
  case right

  fileprivate func arrowEdge(layoutDirection: LayoutDirection) -> Edge {
    switch self {
    case .top: .bottom
    case .bottom: .top
    case .leading: .trailing
    case .trailing: .leading
    case .left:
      layoutDirection == .leftToRight ? .trailing : .leading
    case .right:
      layoutDirection == .leftToRight ? .leading : .trailing
    }
  }
}

public enum SCHoverCardChangeReason: Hashable, Sendable {
  case triggerHover
  case triggerFocus
  case triggerPress
  case contentHover
  case outsidePress
  case escapeKey
  case imperativeAction
}

/// A concurrency-safe command for dismissing the nearest Swiftcn Hover Card.
public struct SCDismissHoverCardAction: @unchecked Sendable {
  private let action: @MainActor () -> Void

  public init(_ action: @escaping @MainActor () -> Void = {}) {
    self.action = action
  }

  @MainActor
  public func callAsFunction() {
    action()
  }
}

private struct SCHoverCardPresentation: Sendable {
  var dismiss = SCDismissHoverCardAction()
}

private struct SCHoverCardPresentationKey: EnvironmentKey {
  static let defaultValue = SCHoverCardPresentation()
}

extension EnvironmentValues {
  /// Dismisses the nearest enclosing hover card.
  public var scDismissHoverCard: SCDismissHoverCardAction {
    get { self[SCHoverCardPresentationKey.self].dismiss }
    set { self[SCHoverCardPresentationKey.self] = SCHoverCardPresentation(dismiss: newValue) }
  }
}

// MARK: - Root

/// A controlled or internally managed preview card with independently
/// composable trigger and content.
///
/// On macOS the card uses SwiftCN's arrowless overlay portal so scroll views,
/// cards, and split-view columns cannot clip it. Hover and focus use
/// caller-configurable delays; touch uses a nonblocking long press as a
/// platform adaptation.
public struct SCHoverCard<Trigger: View, CardContent: View>: View {
  private let externalIsPresented: Binding<Bool>?
  private let defaultPresented: Bool
  private let openDelay: Duration
  private let closeDelay: Duration
  private let side: SCHoverCardSide
  private let isHoverEnabled: Bool
  private let isFocusEnabled: Bool
  private let isLongPressEnabled: Bool
  private let longPressDuration: Double
  private let dismissOnEscape: Bool
  private let onOpenChange: ((Bool, SCHoverCardChangeReason) -> Void)?
  private let onOpenChangeComplete: ((Bool) -> Void)?
  private let trigger: Trigger
  private let cardContent: CardContent

  public init(
    isPresented: Binding<Bool>,
    openDelay: Duration = .milliseconds(600),
    closeDelay: Duration = .milliseconds(300),
    side: SCHoverCardSide = .bottom,
    isHoverEnabled: Bool = true,
    isFocusEnabled: Bool = true,
    isLongPressEnabled: Bool = true,
    longPressDuration: Double = 0.35,
    dismissOnEscape: Bool = true,
    onOpenChange: ((Bool, SCHoverCardChangeReason) -> Void)? = nil,
    onOpenChangeComplete: ((Bool) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder content: () -> CardContent
  ) {
    self.externalIsPresented = isPresented
    self.defaultPresented = isPresented.wrappedValue
    self.openDelay = openDelay
    self.closeDelay = closeDelay
    self.side = side
    self.isHoverEnabled = isHoverEnabled
    self.isFocusEnabled = isFocusEnabled
    self.isLongPressEnabled = isLongPressEnabled
    self.longPressDuration = max(longPressDuration, 0)
    self.dismissOnEscape = dismissOnEscape
    self.onOpenChange = onOpenChange
    self.onOpenChangeComplete = onOpenChangeComplete
    self.trigger = trigger()
    self.cardContent = content()
  }

  public init(
    defaultPresented: Bool = false,
    openDelay: Duration = .milliseconds(600),
    closeDelay: Duration = .milliseconds(300),
    side: SCHoverCardSide = .bottom,
    isHoverEnabled: Bool = true,
    isFocusEnabled: Bool = true,
    isLongPressEnabled: Bool = true,
    longPressDuration: Double = 0.35,
    dismissOnEscape: Bool = true,
    onOpenChange: ((Bool, SCHoverCardChangeReason) -> Void)? = nil,
    onOpenChangeComplete: ((Bool) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder content: () -> CardContent
  ) {
    self.externalIsPresented = nil
    self.defaultPresented = defaultPresented
    self.openDelay = openDelay
    self.closeDelay = closeDelay
    self.side = side
    self.isHoverEnabled = isHoverEnabled
    self.isFocusEnabled = isFocusEnabled
    self.isLongPressEnabled = isLongPressEnabled
    self.longPressDuration = max(longPressDuration, 0)
    self.dismissOnEscape = dismissOnEscape
    self.onOpenChange = onOpenChange
    self.onOpenChangeComplete = onOpenChangeComplete
    self.trigger = trigger()
    self.cardContent = content()
  }

  public var body: some View {
    SCHoverCardStateContainer(
      externalIsPresented: externalIsPresented,
      defaultPresented: defaultPresented,
      openDelay: openDelay,
      closeDelay: closeDelay,
      side: side,
      isHoverEnabled: isHoverEnabled,
      isFocusEnabled: isFocusEnabled,
      isLongPressEnabled: isLongPressEnabled,
      longPressDuration: longPressDuration,
      dismissOnEscape: dismissOnEscape,
      onOpenChange: onOpenChange,
      onOpenChangeComplete: onOpenChangeComplete,
      trigger: trigger,
      cardContent: cardContent
    )
  }
}

// MARK: - Trigger and content parts

/// The arbitrary link, button, or view used as a hover-card trigger.
public struct SCHoverCardTrigger<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View { content }
}

/// Applies the themed hover-card surface to arbitrary preview content.
public struct SCHoverCardContent<Content: View>: View {
  @Environment(\.theme) private var theme

  private let padding: CGFloat
  private let minimumWidth: CGFloat?
  private let idealWidth: CGFloat?
  private let maximumWidth: CGFloat?
  private let content: Content

  public init(
    padding: CGFloat = 16,
    minimumWidth: CGFloat? = 240,
    idealWidth: CGFloat? = 288,
    maximumWidth: CGFloat? = 320,
    @ViewBuilder content: () -> Content
  ) {
    self.padding = max(padding, 0)
    self.minimumWidth = minimumWidth.map { max($0, 0) }
    self.idealWidth = idealWidth.map { max($0, 0) }
    self.maximumWidth = maximumWidth.map { max($0, 0) }
    self.content = content()
  }

  public var body: some View {
    content
      .padding(padding)
      .frame(
        minWidth: minimumWidth,
        idealWidth: idealWidth,
        maxWidth: maximumWidth,
        alignment: .leading
      )
      .foregroundStyle(theme.popoverForeground)
      .background(
        theme.popover,
        in: RoundedRectangle(cornerRadius: theme.radius + 2, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: theme.radius + 2, style: .continuous)
          .strokeBorder(theme.border)
      }
      .presentationBackground(theme.popover)
      .presentationCompactAdaptation(.popover)
  }
}
