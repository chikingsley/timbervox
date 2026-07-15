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
    HStack(alignment: .top, spacing: 12) {
      leading
        .foregroundStyle(foregroundColor)

      VStack(alignment: .leading, spacing: 4) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(background, in: shape)
    .overlay(shape.strokeBorder(strokeColor))
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
    switch variant {
    case .default: theme.background
    case .destructive: theme.destructive.opacity(0.08)
    }
  }

  private var strokeColor: Color {
    switch variant {
    case .default: theme.border
    case .destructive: theme.destructive.opacity(0.5)
    }
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
      .font(.subheadline.weight(.semibold))
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
      .font(.footnote)
      .foregroundStyle(
        variant == .destructive
          ? theme.destructive.opacity(0.9)
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

/// A trailing action region inside an `SCAlert`.
public struct SCAlertAction<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.top, 4)
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
              .font(.system(size: 17, weight: .medium))
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
