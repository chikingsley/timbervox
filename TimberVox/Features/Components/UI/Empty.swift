// ============================================================
// Empty.swift — swiftcn-ui
// Depends on: Theme/ (previews also use Button.swift)
// ============================================================
import SwiftUI

// MARK: - Root

/// A centered empty-state container with caller-composed content.
///
/// Compose `SCEmptyHeader`, `SCEmptyMedia`, `SCEmptyTitle`,
/// `SCEmptyDescription`, and `SCEmptyContent` as needed. Backgrounds, borders,
/// and parent sizing remain ordinary SwiftUI modifiers on this root.
public struct SCEmpty<Content: View>: View {
  private let horizontalPadding: CGFloat
  private let verticalPadding: CGFloat
  private let minimumHeight: CGFloat?
  private let content: Content

  public init(
    horizontalPadding: CGFloat = 24,
    verticalPadding: CGFloat = 48,
    minimumHeight: CGFloat? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.horizontalPadding = max(horizontalPadding, 0)
    self.verticalPadding = max(verticalPadding, 0)
    self.minimumHeight = minimumHeight.map { max($0, 0) }
    self.content = content()
  }

  public var body: some View {
    VStack(spacing: 20) {
      content
    }
    .frame(maxWidth: .infinity, minHeight: minimumHeight)
    .padding(.horizontal, horizontalPadding)
    .padding(.vertical, verticalPadding)
    .multilineTextAlignment(.center)
    .accessibilityElement(children: .contain)
  }
}

// MARK: - Header

/// The centered, width-constrained heading region of an empty state.
public struct SCEmptyHeader<Content: View>: View {
  private let maximumWidth: CGFloat?
  private let spacing: CGFloat
  private let content: Content

  public init(
    maximumWidth: CGFloat? = 384,
    spacing: CGFloat = 8,
    @ViewBuilder content: () -> Content
  ) {
    self.maximumWidth = maximumWidth.map { max($0, 0) }
    self.spacing = max(spacing, 0)
    self.content = content()
  }

  public var body: some View {
    VStack(spacing: spacing) {
      content
    }
    .frame(maxWidth: maximumWidth)
  }
}

// MARK: - Media

public enum SCEmptyMediaVariant: Hashable, Sendable {
  /// Leaves the caller's media unframed.
  case `default`
  /// Places compact media in a muted rounded container.
  case icon
}

/// Arbitrary empty-state media with either unframed or icon treatment.
public struct SCEmptyMedia<Content: View>: View {
  @Environment(\.theme) private var theme

  private let variant: SCEmptyMediaVariant
  private let isDecorative: Bool
  private let content: Content

  public init(
    variant: SCEmptyMediaVariant = .default,
    isDecorative: Bool = true,
    @ViewBuilder content: () -> Content
  ) {
    self.variant = variant
    self.isDecorative = isDecorative
    self.content = content()
  }

  @ViewBuilder
  public var body: some View {
    switch variant {
    case .default:
      content
        .accessibilityHidden(isDecorative)
    case .icon:
      content
        .font(.title3)
        .foregroundStyle(theme.foreground)
        .frame(width: 48, height: 48)
        .background(theme.muted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(isDecorative)
    }
  }
}

// MARK: - Text regions

/// The arbitrary heading of an empty state.
public struct SCEmptyTitle<Content: View>: View {
  @Environment(\.theme) private var theme

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .font(.headline)
      .foregroundStyle(theme.foreground)
      .accessibilityAddTraits(.isHeader)
  }
}

extension SCEmptyTitle where Content == Text {
  public init(_ title: String) {
    self.init { Text(title) }
  }
}

/// Arbitrary supporting content using the muted foreground treatment.
public struct SCEmptyDescription<Content: View>: View {
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

extension SCEmptyDescription where Content == Text {
  public init(_ description: String) {
    self.init { Text(description) }
  }
}

// MARK: - Content

/// A centered, width-constrained region for actions, inputs, links, or any
/// other caller-composed recovery UI.
public struct SCEmptyContent<Content: View>: View {
  private let maximumWidth: CGFloat?
  private let spacing: CGFloat
  private let content: Content

  public init(
    maximumWidth: CGFloat? = 384,
    spacing: CGFloat = 12,
    @ViewBuilder content: () -> Content
  ) {
    self.maximumWidth = maximumWidth.map { max($0, 0) }
    self.spacing = max(spacing, 0)
    self.content = content()
  }

  public var body: some View {
    VStack(spacing: spacing) {
      content
    }
    .frame(maxWidth: maximumWidth)
  }
}

// MARK: - Convenience composition

extension SCEmpty where Content == AnyView {
  /// A compact title/description/media/actions initializer composed entirely
  /// from the same public empty-state parts.
  public init<Media: View, Actions: View>(
    _ title: String,
    description: String? = nil,
    mediaVariant: SCEmptyMediaVariant = .icon,
    horizontalPadding: CGFloat = 24,
    verticalPadding: CGFloat = 48,
    minimumHeight: CGFloat? = nil,
    @ViewBuilder icon: () -> Media = { EmptyView() },
    @ViewBuilder actions: () -> Actions = { EmptyView() }
  ) {
    let media = icon()
    let actionContent = actions()

    self.init(
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      minimumHeight: minimumHeight
    ) {
      AnyView(
        Group {
          SCEmptyHeader {
            if Media.self != EmptyView.self {
              SCEmptyMedia(variant: mediaVariant) {
                media
              }
            }
            SCEmptyTitle(title)
            if let description {
              SCEmptyDescription(description)
            }
          }
          if Actions.self != EmptyView.self {
            SCEmptyContent {
              actionContent
            }
          }
        }
      )
    }
  }

  /// Convenience for an SF Symbol media slot.
  public init<Actions: View>(
    _ title: String,
    systemImage: String,
    description: String? = nil,
    mediaVariant: SCEmptyMediaVariant = .icon,
    horizontalPadding: CGFloat = 24,
    verticalPadding: CGFloat = 48,
    minimumHeight: CGFloat? = nil,
    @ViewBuilder actions: () -> Actions = { EmptyView() }
  ) {
    self.init(
      title,
      description: description,
      mediaVariant: mediaVariant,
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      minimumHeight: minimumHeight,
      icon: { Image(systemName: systemImage) },
      actions: actions
    )
  }
}
