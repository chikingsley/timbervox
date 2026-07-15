import SwiftUI

// MARK: - Shared state engine

struct SCHoverCardStateContainer<Trigger: View, CardContent: View>: View {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.layoutDirection) private var layoutDirection

  @State private var internalIsPresented: Bool
  @State private var openTask: Task<Void, Never>?
  @State private var closeTask: Task<Void, Never>?
  @FocusState private var isTriggerFocused: Bool

  let externalIsPresented: Binding<Bool>?
  let openDelay: Duration
  let closeDelay: Duration
  let side: SCHoverCardSide
  let isHoverEnabled: Bool
  let isFocusEnabled: Bool
  let isLongPressEnabled: Bool
  let longPressDuration: Double
  let dismissOnEscape: Bool
  let onOpenChange: ((Bool, SCHoverCardChangeReason) -> Void)?
  let onOpenChangeComplete: ((Bool) -> Void)?
  let trigger: Trigger
  let cardContent: CardContent

  init(
    externalIsPresented: Binding<Bool>?,
    defaultPresented: Bool,
    openDelay: Duration,
    closeDelay: Duration,
    side: SCHoverCardSide,
    isHoverEnabled: Bool,
    isFocusEnabled: Bool,
    isLongPressEnabled: Bool,
    longPressDuration: Double,
    dismissOnEscape: Bool,
    onOpenChange: ((Bool, SCHoverCardChangeReason) -> Void)?,
    onOpenChangeComplete: ((Bool) -> Void)?,
    trigger: Trigger,
    cardContent: CardContent
  ) {
    self.externalIsPresented = externalIsPresented
    self._internalIsPresented = State(initialValue: defaultPresented)
    self.openDelay = openDelay
    self.closeDelay = closeDelay
    self.side = side
    self.isHoverEnabled = isHoverEnabled
    self.isFocusEnabled = isFocusEnabled
    self.isLongPressEnabled = isLongPressEnabled
    self.longPressDuration = longPressDuration
    self.dismissOnEscape = dismissOnEscape
    self.onOpenChange = onOpenChange
    self.onOpenChangeComplete = onOpenChangeComplete
    self.trigger = trigger
    self.cardContent = cardContent
  }

  var body: some View {
    trigger
      .focusable(isFocusEnabled)
      .focused($isTriggerFocused)
      .onChange(of: isTriggerFocused) { _, focused in
        guard isFocusEnabled else { return }
        if focused {
          scheduleOpen(reason: .triggerFocus)
        } else {
          scheduleClose(reason: .triggerFocus)
        }
      }
      .onHover { hovering in
        guard isHoverEnabled else { return }
        if hovering {
          scheduleOpen(reason: .triggerHover)
        } else {
          scheduleClose(reason: .triggerHover)
        }
      }
      .modifier(
        SCHoverCardLongPressModifier(
          isEnabled: isEnabled && isLongPressEnabled,
          minimumDuration: longPressDuration
        ) { setPresented(true, reason: .triggerPress) }
      )
      .background {
        SCOverlayPortal(
          isPresented: presentationBinding,
          width: 288,
          maxHeight: 360,
          gap: 8,
          side: overlaySide,
          alignment: .start,
          acceptsKey: false
        ) {
          card
        }
      }
      .scHoverCardEscapeDismiss(
        isEnabled: dismissOnEscape,
        isPresented: isPresented
      ) { setPresented(false, reason: .escapeKey) }
      .onDisappear { cancelTasks() }
  }

  private var card: some View {
    cardContent
      .environment(
        \.scDismissHoverCard,
        SCDismissHoverCardAction {
          setPresented(false, reason: .imperativeAction)
        }
      )
      .onHover { hovering in
        guard isHoverEnabled else { return }
        if hovering {
          closeTask?.cancel()
        } else {
          scheduleClose(reason: .contentHover)
        }
      }
      .onAppear { onOpenChangeComplete?(true) }
      .onDisappear { onOpenChangeComplete?(false) }
  }

  private var overlaySide: SCOverlaySide {
    switch side {
    case .top: .top
    case .bottom: .bottom
    case .leading: layoutDirection == .leftToRight ? .leading : .trailing
    case .trailing: layoutDirection == .leftToRight ? .trailing : .leading
    case .left: .leading
    case .right: .trailing
    }
  }

  private var isPresented: Bool {
    externalIsPresented?.wrappedValue ?? internalIsPresented
  }

  private var presentationBinding: Binding<Bool> {
    Binding(
      get: { isPresented },
      set: { presented in
        setPresented(
          presented,
          reason: presented ? .imperativeAction : .outsidePress
        )
      }
    )
  }

  private func setPresented(
    _ presented: Bool,
    reason: SCHoverCardChangeReason
  ) {
    cancelTasks()
    guard presented != isPresented else { return }
    if let externalIsPresented {
      externalIsPresented.wrappedValue = presented
    } else {
      internalIsPresented = presented
    }
    onOpenChange?(presented, reason)
  }

  private func scheduleOpen(reason: SCHoverCardChangeReason) {
    guard isEnabled, !isPresented else { return }
    closeTask?.cancel()
    openTask?.cancel()
    openTask = Task { @MainActor in
      try? await Task.sleep(for: openDelay)
      guard !Task.isCancelled else { return }
      setPresented(true, reason: reason)
    }
  }

  private func scheduleClose(reason: SCHoverCardChangeReason) {
    guard isPresented else {
      openTask?.cancel()
      return
    }
    openTask?.cancel()
    closeTask?.cancel()
    closeTask = Task { @MainActor in
      try? await Task.sleep(for: closeDelay)
      guard !Task.isCancelled else { return }
      setPresented(false, reason: reason)
    }
  }

  private func cancelTasks() {
    openTask?.cancel()
    closeTask?.cancel()
  }
}

private struct SCHoverCardLongPressModifier: ViewModifier {
  let isEnabled: Bool
  let minimumDuration: Double
  let action: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    #if os(iOS)
      if isEnabled {
        content.simultaneousGesture(
          LongPressGesture(minimumDuration: minimumDuration)
            .onEnded { _ in action() }
        )
      } else {
        content
      }
    #else
      content
    #endif
  }
}

extension View {
  @ViewBuilder
  fileprivate func scHoverCardEscapeDismiss(
    isEnabled: Bool,
    isPresented: Bool,
    action: @escaping () -> Void
  ) -> some View {
    #if os(macOS)
      onExitCommand {
        guard isEnabled, isPresented else { return }
        action()
      }
    #else
      self
    #endif
  }
}

// MARK: - Modifier convenience

extension View {
  /// Convenience composition over the same root, scheduling, and native
  /// popover engine as `SCHoverCard`.
  public func scHoverCard<CardContent: View>(
    isPresented: Binding<Bool>? = nil,
    openDelay: Duration = .milliseconds(600),
    closeDelay: Duration = .milliseconds(300),
    side: SCHoverCardSide = .bottom,
    isHoverEnabled: Bool = true,
    isFocusEnabled: Bool = true,
    isLongPressEnabled: Bool = true,
    longPressDuration: Double = 0.35,
    dismissOnEscape: Bool = true,
    onOpenChange: ((Bool, SCHoverCardChangeReason) -> Void)? = nil,
    @ViewBuilder content: () -> CardContent
  ) -> some View {
    Group {
      if let isPresented {
        SCHoverCard(
          isPresented: isPresented,
          openDelay: openDelay,
          closeDelay: closeDelay,
          side: side,
          isHoverEnabled: isHoverEnabled,
          isFocusEnabled: isFocusEnabled,
          isLongPressEnabled: isLongPressEnabled,
          longPressDuration: longPressDuration,
          dismissOnEscape: dismissOnEscape,
          onOpenChange: onOpenChange,
          trigger: { self },
          content: { SCHoverCardContent(content: content) }
        )
      } else {
        SCHoverCard(
          openDelay: openDelay,
          closeDelay: closeDelay,
          side: side,
          isHoverEnabled: isHoverEnabled,
          isFocusEnabled: isFocusEnabled,
          isLongPressEnabled: isLongPressEnabled,
          longPressDuration: longPressDuration,
          dismissOnEscape: dismissOnEscape,
          onOpenChange: onOpenChange,
          trigger: { self },
          content: { SCHoverCardContent(content: content) }
        )
      }
    }
  }
}
