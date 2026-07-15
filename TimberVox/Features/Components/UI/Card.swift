// ============================================================
// Card.swift — swiftcn-ui
// Depends on: Theme/
// ============================================================
import SwiftUI

public enum SCCardSize: CaseIterable, Sendable {
  case `default`, sm
}

private struct SCCardSizeKey: EnvironmentKey {
  static let defaultValue = SCCardSize.default
}

extension EnvironmentValues {
  fileprivate var scCardSize: SCCardSize {
    get { self[SCCardSizeKey.self] }
    set { self[SCCardSizeKey.self] = newValue }
  }
}

// MARK: - Root

/// A themed surface composed from Header, Content, and Footer regions.
public struct SCCard<Content: View>: View {
  @Environment(\.theme) private var theme

  private let size: SCCardSize
  private let content: Content

  public init(
    size: SCCardSize = .default,
    @ViewBuilder content: () -> Content
  ) {
    self.size = size
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      content
    }
    .padding(.vertical, verticalInset)
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(theme.cardForeground)
    .background(theme.card, in: shape)
    .overlay { shape.strokeBorder(theme.border) }
    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    .environment(\.scCardSize, size)
  }

  private var sectionSpacing: CGFloat { size == .sm ? 16 : 24 }
  private var verticalInset: CGFloat { size == .sm ? 16 : 24 }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: theme.radius + 2, style: .continuous)
  }
}

// MARK: - Header

private enum SCCardHeaderRole {
  case content, action
}

private struct SCCardHeaderRoleKey: LayoutValueKey {
  static let defaultValue = SCCardHeaderRole.content
}

/// A card heading grid. An `SCCardAction` child is placed top-trailing while
/// all other children form the title/description column.
public struct SCCardHeader<Content: View>: View {
  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(\.scCardSize) private var size

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    SCCardHeaderLayout(
      columnSpacing: size == .sm ? 8 : 12,
      rowSpacing: size == .sm ? 4 : 6,
      layoutDirection: layoutDirection
    ) {
      content
    }
    .padding(.horizontal, horizontalInset)
  }

  private var horizontalInset: CGFloat { size == .sm ? 16 : 24 }
}

extension SCCardHeader {
  /// Compatibility initializer for the earlier explicit action slot.
  public init<Header: View, Action: View>(
    @ViewBuilder content: () -> Header,
    @ViewBuilder action: () -> Action
  ) where Content == TupleView<(Header, SCCardAction<Action>)> {
    self.init {
      content()
      SCCardAction { action() }
    }
  }
}

private struct SCCardHeaderLayout: Layout {
  var columnSpacing: CGFloat
  var rowSpacing: CGFloat
  var layoutDirection: LayoutDirection

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Void
  ) -> CGSize {
    let action = subviews.first { $0[SCCardHeaderRoleKey.self] == .action }
    let actionSize = action?.sizeThatFits(.unspecified) ?? .zero
    let contentSubviews = subviews.filter { $0[SCCardHeaderRoleKey.self] != .action }
    let proposedWidth = proposal.width
    let contentWidth = proposedWidth.map {
      max($0 - (action == nil ? 0 : actionSize.width + columnSpacing), 0)
    }
    let contentSizes = contentSubviews.map {
      $0.sizeThatFits(ProposedViewSize(width: contentWidth, height: nil))
    }
    let contentHeight = contentSizes.enumerated().reduce(CGFloat.zero) { partial, entry in
      partial + entry.element.height + (entry.offset == 0 ? 0 : rowSpacing)
    }
    let intrinsicContentWidth = contentSizes.map(\.width).max() ?? 0
    let intrinsicWidth =
      intrinsicContentWidth
      + (action == nil ? 0 : actionSize.width + columnSpacing)
    return CGSize(
      width: proposedWidth ?? intrinsicWidth,
      height: max(contentHeight, actionSize.height)
    )
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Void
  ) {
    let action = subviews.first { $0[SCCardHeaderRoleKey.self] == .action }
    let actionSize = action?.sizeThatFits(.unspecified) ?? .zero
    let contentWidth = max(
      bounds.width - (action == nil ? 0 : actionSize.width + columnSpacing),
      0
    )
    let contentX =
      layoutDirection == .leftToRight
      ? bounds.minX : bounds.maxX - contentWidth
    var y = bounds.minY

    for subview in subviews where subview[SCCardHeaderRoleKey.self] != .action {
      let size = subview.sizeThatFits(
        ProposedViewSize(width: contentWidth, height: nil)
      )
      subview.place(
        at: CGPoint(x: contentX, y: y),
        anchor: .topLeading,
        proposal: ProposedViewSize(width: contentWidth, height: size.height)
      )
      y += size.height + rowSpacing
    }

    if let action {
      let actionX =
        layoutDirection == .leftToRight
        ? bounds.maxX - actionSize.width : bounds.minX
      action.place(
        at: CGPoint(x: actionX, y: bounds.minY),
        anchor: .topLeading,
        proposal: ProposedViewSize(actionSize)
      )
    }
  }
}

// MARK: - Header parts

/// A top-trailing action recognized automatically by `SCCardHeader`.
public struct SCCardAction<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content.layoutValue(key: SCCardHeaderRoleKey.self, value: .action)
  }
}

/// Arbitrary heading content with card typography and header semantics.
public struct SCCardTitle<Content: View>: View {
  @Environment(\.theme) private var theme

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .font(.headline.weight(.semibold))
      .foregroundStyle(theme.cardForeground)
      .accessibilityAddTraits(.isHeader)
  }
}

extension SCCardTitle where Content == Text {
  public init(_ title: String) {
    self.init { Text(title) }
  }

  public init(_ text: Text) {
    self.init { text }
  }
}

/// Arbitrary supporting content in the muted foreground style.
public struct SCCardDescription<Content: View>: View {
  @Environment(\.theme) private var theme

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .font(.subheadline)
      .foregroundStyle(theme.mutedForeground)
  }
}

extension SCCardDescription where Content == Text {
  public init(_ description: String) {
    self.init { Text(description) }
  }

  public init(_ text: Text) {
    self.init { text }
  }
}

// MARK: - Content and footer

/// The card's arbitrary main content region.
public struct SCCardContent<Content: View>: View {
  @Environment(\.scCardSize) private var size

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      content
    }
    .padding(.horizontal, size == .sm ? 16 : 24)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A horizontally composed footer region with arbitrary controls or content.
public struct SCCardFooter<Content: View>: View {
  @Environment(\.scCardSize) private var size

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    HStack(spacing: 8) {
      content
    }
    .padding(.horizontal, size == .sm ? 16 : 24)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
