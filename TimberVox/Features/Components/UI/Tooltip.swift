// Tooltip.swift — swiftcn-ui
// Depends on: Theme/
import Observation
import SwiftUI

// MARK: - Provider

/// Owns tooltip presentation for a view hierarchy. Like shadcn/ui's
/// `TooltipProvider`, the provider renders tooltip content above the controls
/// that trigger it, so clipping containers such as sidebars and scroll views
/// do not crop the bubble.
public struct SCTooltipProvider<Content: View>: View {
  @State private var coordinator: SCTooltipCoordinator
  @State private var providerSize = CGSize.zero
  @State private var bubbleSize = CGSize.zero

  private let content: Content

  /// Creates the presentation layer. The default delay matches shadcn/ui's
  /// current `TooltipProvider`; pass a nonzero duration when an application
  /// deliberately wants delayed pointer disclosure.
  public init(delay: Duration = .zero, @ViewBuilder content: () -> Content) {
    _coordinator = State(initialValue: SCTooltipCoordinator(delay: delay))
    self.content = content()
  }

  public var body: some View {
    content
      .environment(\.scTooltipCoordinator, coordinator)
      .overlay(alignment: .topLeading) {
        if let presentation = coordinator.presentation {
          SCTooltipContent(presentation.text, side: presentation.edge)
            .background {
              GeometryReader { proxy in
                Color.clear
                  .onAppear { updateBubbleSize(proxy.size) }
                  .onChange(of: proxy.size) { _, size in updateBubbleSize(size) }
              }
            }
            .position(position(for: presentation))
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .zIndex(10_000)
        }
      }
      .background {
        GeometryReader { proxy in
          Color.clear
            .onAppear { updateProviderSize(proxy.size) }
            .onChange(of: proxy.size) { _, size in updateProviderSize(size) }
        }
      }
      .coordinateSpace(name: SCTooltipCoordinateSpace.name)
      .animation(.snappy(duration: 0.18), value: coordinator.presentation?.id)
  }

  private func updateProviderSize(_ size: CGSize) {
    guard providerSize != size else { return }
    providerSize = size
  }

  private func updateBubbleSize(_ size: CGSize) {
    guard bubbleSize != size else { return }
    bubbleSize = size
  }

  private func position(for presentation: SCTooltipPresentation) -> CGPoint {
    let gap: CGFloat = 8
    let desired: CGPoint

    switch presentation.edge {
    case .top:
      desired = CGPoint(
        x: presentation.anchor.midX,
        y: presentation.anchor.minY - gap - bubbleSize.height / 2
      )
    case .bottom:
      desired = CGPoint(
        x: presentation.anchor.midX,
        y: presentation.anchor.maxY + gap + bubbleSize.height / 2
      )
    case .leading:
      desired = CGPoint(
        x: presentation.anchor.minX - gap - bubbleSize.width / 2,
        y: presentation.anchor.midY
      )
    case .trailing:
      desired = CGPoint(
        x: presentation.anchor.maxX + gap + bubbleSize.width / 2,
        y: presentation.anchor.midY
      )
    }

    let margin: CGFloat = 8
    return CGPoint(
      x: min(
        max(desired.x, margin + bubbleSize.width / 2),
        max(margin + bubbleSize.width / 2, providerSize.width - margin - bubbleSize.width / 2)
      ),
      y: min(
        max(desired.y, margin + bubbleSize.height / 2),
        max(
          margin + bubbleSize.height / 2,
          providerSize.height - margin - bubbleSize.height / 2
        )
      )
    )
  }
}

extension View {
  /// Installs one tooltip presentation layer for this view hierarchy.
  public func scTooltipProvider(delay: Duration = .zero) -> some View {
    SCTooltipProvider(delay: delay) { self }
  }
}

// MARK: - Root, trigger, and content

/// A tooltip root whose closure is the trigger, mirroring shadcn/ui's
/// `Tooltip` plus `TooltipTrigger` composition in a SwiftUI-native shape.
///
/// Use this form when the trigger itself is disabled so the outer tooltip root
/// can continue to receive pointer events.
///
///     SCTooltip("Unavailable while syncing") {
///         Button("Delete") {}
///             .disabled(true)
///     }
public struct SCTooltip<Trigger: View>: View {
  private let text: String
  private let side: Edge
  private let trigger: Trigger

  public init(
    _ text: String,
    side: Edge = .top,
    @ViewBuilder trigger: () -> Trigger
  ) {
    self.text = text
    self.side = side
    self.trigger = trigger()
  }

  public var body: some View {
    trigger.modifier(SCTooltipModifier(text: text, edge: side))
  }
}

/// The themed tooltip bubble rendered by `SCTooltipProvider`, corresponding
/// to shadcn/ui's `TooltipContent`. Most callers use `SCTooltip` or
/// `.scTooltip(_:)` and do not create this surface directly.
public struct SCTooltipContent: View {
  @Environment(\.theme) private var theme

  private let text: String
  private let side: Edge

  public init(_ text: String, side: Edge = .top) {
    self.text = text
    self.side = side
  }

  public var body: some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(theme.primaryForeground)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(theme.primary, in: shape)
      .overlay(alignment: arrowAlignment) {
        RoundedRectangle(cornerRadius: 1.5)
          .fill(theme.primary)
          .frame(width: 8, height: 8)
          .rotationEffect(.degrees(45))
          .offset(arrowOffset)
      }
      .fixedSize()
      .shadow(color: theme.foreground.opacity(0.08), radius: 4, y: 2)
      .accessibilityHidden(true)
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: max(theme.radius - 4, 4), style: .continuous)
  }

  private var arrowAlignment: Alignment {
    switch side {
    case .top: .bottom
    case .bottom: .top
    case .leading: .trailing
    case .trailing: .leading
    }
  }

  private var arrowOffset: CGSize {
    switch side {
    case .top: CGSize(width: 0, height: 3)
    case .bottom: CGSize(width: 0, height: -3)
    case .leading: CGSize(width: 3, height: 0)
    case .trailing: CGSize(width: -3, height: 0)
    }
  }
}

// MARK: - Convenience modifier

extension View {
  /// Shows a small text bubble beside the view — the swiftcn port of
  /// shadcn/ui's Tooltip.
  ///
  /// On pointer platforms (macOS, iPadOS) the bubble appears on hover or
  /// keyboard focus and hides when neither remains active. On touch, a
  /// 0.35s long-press shows the bubble for 2 seconds.
  ///
  /// Install `.scTooltipProvider()` once near the root of the consuming
  /// view hierarchy. Without a provider, macOS falls back to native help.
  ///
  ///     Button("Add to library") { addToLibrary() }
  ///         .buttonStyle(.sc(.outline))
  ///         .scTooltip("Add to library")
  public func scTooltip(_ text: String, edge: Edge = .top) -> some View {
    modifier(SCTooltipModifier(text: text, edge: edge))
  }
}

private struct SCTooltipModifier: ViewModifier {
  @Environment(\.scTooltipCoordinator) private var coordinator
  @Environment(\.isEnabled) private var isEnabled

  let text: String
  let edge: Edge

  @State private var id = UUID()
  @State private var anchor = CGRect.zero
  @State private var showTask: Task<Void, Never>?
  @State private var hideTask: Task<Void, Never>?
  @State private var isHovering = false
  @FocusState private var isFocused: Bool

  func body(content: Content) -> some View {
    tooltipAnchor(content)
      .focused($isFocused)
      .onHover(perform: handleHover)
      .onChange(of: isFocused) { _, focused in handleFocus(focused) }
      .scTooltipTouchActivation(perform: showTemporarily)
      .scTooltipAccessibility(text, usesNativeHelp: coordinator == nil)
      .onDisappear {
        showTask?.cancel()
        hideTask?.cancel()
        coordinator?.hide(id: id)
      }
  }

  private func tooltipAnchor(_ content: Content) -> some View {
    content
      .background {
        GeometryReader { proxy in
          Color.clear.preference(
            key: SCTooltipAnchorPreferenceKey.self,
            value: proxy.frame(in: .named(SCTooltipCoordinateSpace.name))
          )
        }
      }
      .onPreferenceChange(SCTooltipAnchorPreferenceKey.self) { frame in
        guard anchor != frame else { return }
        anchor = frame
        coordinator?.updateAnchor(frame, id: id)
      }
  }

  private func handleHover(_ hovering: Bool) {
    isHovering = hovering
    guard isEnabled, let coordinator else { return }
    if hovering {
      scheduleShow(using: coordinator)
    } else if !isFocused {
      showTask?.cancel()
      coordinator.hide(id: id)
    }
  }

  private func handleFocus(_ focused: Bool) {
    guard isEnabled, let coordinator else { return }
    if focused {
      scheduleShow(using: coordinator)
    } else if !isHovering {
      showTask?.cancel()
      coordinator.hide(id: id)
    }
  }

  private func scheduleShow(using coordinator: SCTooltipCoordinator) {
    hideTask?.cancel()
    showTask?.cancel()
    showTask = Task { @MainActor in
      try? await Task.sleep(for: coordinator.delay)
      guard !Task.isCancelled else { return }
      coordinator.show(id: id, text: text, edge: edge, anchor: anchor)
    }
  }

  private func showTemporarily() {
    guard isEnabled, let coordinator else { return }
    showTask?.cancel()
    hideTask?.cancel()
    coordinator.show(id: id, text: text, edge: edge, anchor: anchor)
    hideTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      coordinator.hide(id: id)
    }
  }
}

// MARK: - Presentation state

private struct SCTooltipPresentation: Equatable {
  let id: UUID
  let text: String
  let edge: Edge
  var anchor: CGRect
}

@Observable
@MainActor
private final class SCTooltipCoordinator {
  let delay: Duration
  var presentation: SCTooltipPresentation?

  nonisolated init(delay: Duration) {
    self.delay = delay
  }

  func show(id: UUID, text: String, edge: Edge, anchor: CGRect) {
    let next = SCTooltipPresentation(id: id, text: text, edge: edge, anchor: anchor)
    guard presentation != next else { return }
    presentation = next
  }

  func hide(id: UUID) {
    guard presentation?.id == id else { return }
    presentation = nil
  }

  func updateAnchor(_ anchor: CGRect, id: UUID) {
    guard var current = presentation, current.id == id, current.anchor != anchor else { return }
    current.anchor = anchor
    presentation = current
  }
}

private struct SCTooltipCoordinatorKey: EnvironmentKey {
  static var defaultValue: SCTooltipCoordinator? { nil }
}

extension EnvironmentValues {
  fileprivate var scTooltipCoordinator: SCTooltipCoordinator? {
    get { self[SCTooltipCoordinatorKey.self] }
    set { self[SCTooltipCoordinatorKey.self] = newValue }
  }
}

private enum SCTooltipCoordinateSpace {
  static let name = "sc-tooltip-provider"
}

private struct SCTooltipAnchorPreferenceKey: PreferenceKey {
  static let defaultValue = CGRect.zero

  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
  }
}

// MARK: - Platform helpers

extension View {
  @ViewBuilder
  fileprivate func scTooltipTouchActivation(perform action: @escaping () -> Void) -> some View {
    #if os(iOS)
      onLongPressGesture(minimumDuration: 0.35, perform: action)
    #else
      self
    #endif
  }

  @ViewBuilder
  fileprivate func scTooltipAccessibility(_ text: String, usesNativeHelp: Bool) -> some View {
    #if os(macOS)
      if usesNativeHelp {
        help(text)
      } else {
        accessibilityHint(Text(text))
      }
    #else
      accessibilityHint(Text(text))
    #endif
  }
}
