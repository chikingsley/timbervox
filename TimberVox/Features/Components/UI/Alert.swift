// ============================================================
// Alert.swift — swiftcn-ui
// Depends on: Theme/
// ============================================================
import SwiftUI

// MARK: - Variants

public enum SCAlertVariant: CaseIterable, Equatable, Sendable {
  case `default`, destructive
}

// MARK: - Root

/// An inline callout for information that requires the user's attention.
///
/// Compose the content with `SCAlertTitle`, `SCAlertDescription`, and an
/// optional `SCAlertAction`. The optional leading slot accepts any SwiftUI
/// view, not only an SF Symbol.
public struct SCAlert<Leading: View, Content: View>: View {
  @Environment(\.theme) private var theme
  @Environment(\.layoutDirection) private var layoutDirection

  private let variant: SCAlertVariant
  private let leading: Leading
  private let content: Content

  /// Creates an alert with arbitrary content and an arbitrary leading view.
  public init(
    variant: SCAlertVariant = .default,
    @ViewBuilder content: () -> Content,
    @ViewBuilder leading: () -> Leading
  ) {
    self.variant = variant
    self.leading = leading()
    self.content = content()
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 10) {
      leading
        .foregroundStyle(foregroundColor)

      SCAlertContentLayout(layoutDirection: layoutDirection) {
        content
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(background, in: shape)
    .overlay {
      shape
        .strokeBorder(strokeColor)
        .allowsHitTesting(false)
    }
    .environment(\.scAlertVariant, variant)
    .accessibilityElement(children: .contain)
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
  }

  private var foregroundColor: Color {
    variant == .destructive ? theme.destructive : theme.foreground
  }

  private var background: Color {
    // Both variants stay untinted, matching upstream's bg-card: the
    // former 8% destructive tint dropped the destructive title below
    // WCAG AA (4.14:1 light / 4.05:1 dark).
    theme.card
  }

  private var strokeColor: Color {
    theme.border
  }
}

extension SCAlert where Leading == EmptyView {
  /// Creates an alert without a leading view.
  public init(
    variant: SCAlertVariant = .default,
    @ViewBuilder content: () -> Content
  ) {
    self.init(variant: variant, content: content) { EmptyView() }
  }
}

// MARK: - Title

/// The alert's heading slot.
public struct SCAlertTitle<Content: View>: View {
  @Environment(\.theme) private var theme
  @Environment(\.scAlertVariant) private var variant

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .font(.subheadline.weight(.medium))
      .foregroundStyle(
        variant == .destructive ? theme.destructive : theme.foreground
      )
  }
}

extension SCAlertTitle where Content == Text {
  public init(_ text: String) {
    self.init { Text(text) }
  }
}

// MARK: - Description

/// The alert's supporting-content slot.
public struct SCAlertDescription<Content: View>: View {
  @Environment(\.theme) private var theme
  @Environment(\.scAlertVariant) private var variant

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .font(.subheadline)
      .foregroundStyle(
        // Full-strength destructive, deviating from upstream's /90
        // opacity, which measures below WCAG AA for footnote text.
        variant == .destructive
          ? theme.destructive
          : theme.mutedForeground
      )
  }
}

extension SCAlertDescription where Content == Text {
  public init(_ text: String) {
    self.init { Text(text) }
  }
}

// MARK: - Action

private enum SCAlertContentRole {
  case content, action
}

private struct SCAlertContentRoleKey: LayoutValueKey {
  static let defaultValue = SCAlertContentRole.content
}

/// A top-trailing action recognized automatically by the alert, mirroring
/// upstream's `absolute top-2.5 right-3` placement. Following the accepted
/// `SCCardHeader` pattern, a native `Layout` reserves the action's width so
/// it shares the title's row instead of overlapping wrapped text.
public struct SCAlertAction<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .layoutValue(key: SCAlertContentRoleKey.self, value: .action)
  }
}

private struct SCAlertContentLayout: Layout {
  var rowSpacing: CGFloat = 4
  var columnSpacing: CGFloat = 12
  var layoutDirection: LayoutDirection

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    let action = subviews.first { $0[SCAlertContentRoleKey.self] == .action }
    let actionSize = action?.sizeThatFits(.unspecified) ?? .zero
    let reserved = action == nil ? 0 : actionSize.width + columnSpacing
    let contentSubviews = subviews.filter { $0[SCAlertContentRoleKey.self] != .action }
    let contentWidth = proposal.width.map { max($0 - reserved, 0) }
    let sizes = contentSubviews.map {
      $0.sizeThatFits(ProposedViewSize(width: contentWidth, height: nil))
    }
    let contentHeight = sizes.enumerated().reduce(CGFloat.zero) { partial, entry in
      partial + entry.element.height + (entry.offset == 0 ? 0 : rowSpacing)
    }
    let intrinsicWidth = (sizes.map(\.width).max() ?? 0) + reserved
    return CGSize(
      width: proposal.width ?? intrinsicWidth,
      height: max(contentHeight, actionSize.height)
    )
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
    let action = subviews.first { $0[SCAlertContentRoleKey.self] == .action }
    let actionSize = action?.sizeThatFits(.unspecified) ?? .zero
    let reserved = action == nil ? 0 : actionSize.width + columnSpacing
    let contentWidth = max(bounds.width - reserved, 0)
    let contentX = layoutDirection == .leftToRight ? bounds.minX : bounds.maxX - contentWidth
    var y = bounds.minY

    for subview in subviews where subview[SCAlertContentRoleKey.self] != .action {
      let size = subview.sizeThatFits(ProposedViewSize(width: contentWidth, height: nil))
      subview.place(
        at: CGPoint(x: contentX, y: y),
        anchor: .topLeading,
        proposal: ProposedViewSize(width: contentWidth, height: size.height)
      )
      y += size.height + rowSpacing
    }

    if let action {
      let actionX = layoutDirection == .leftToRight ? bounds.maxX - actionSize.width : bounds.minX
      action.place(
        at: CGPoint(x: actionX, y: bounds.minY),
        anchor: .topLeading,
        proposal: ProposedViewSize(actionSize)
      )
    }
  }
}

// MARK: - Convenience compositions

extension SCAlert where Leading == AnyView, Content == AnyView {
  /// Convenience for an SF Symbol plus arbitrary alert content.
  public init<Body: View>(
    variant: SCAlertVariant = .default,
    icon: String?,
    @ViewBuilder content: () -> Body
  ) {
    self.init(variant: variant) {
      AnyView(content())
    } leading: {
      AnyView(
        Group {
          if let icon {
            Image(systemName: icon)
              .font(.system(size: 16))
              .accessibilityHidden(true)
          }
        }
      )
    }
  }

  /// Convenience for the common icon, title, and description composition.
  public init(
    icon: String? = nil,
    title: String,
    description: String? = nil,
    variant: SCAlertVariant = .default
  ) {
    self.init(variant: variant, icon: icon) {
      SCAlertTitle(title)
      if let description {
        SCAlertDescription(description)
      }
    }
  }
}

// MARK: - Environment plumbing

private struct SCAlertVariantKey: EnvironmentKey {
  static let defaultValue: SCAlertVariant = .default
}

extension EnvironmentValues {
  fileprivate var scAlertVariant: SCAlertVariant {
    get { self[SCAlertVariantKey.self] }
    set { self[SCAlertVariantKey.self] = newValue }
  }
}
