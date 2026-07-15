// ============================================================
// Skeleton.swift — swiftcn-ui
// Depends on: Theme/
// ============================================================
import SwiftUI

// MARK: - Component

/// Animation supplied by the one Skeleton rendering engine.
public enum SCSkeletonAnimation: CaseIterable, Hashable, Sendable {
  /// The shadcn default: the placeholder gently fades in and out.
  case pulse
  /// A SwiftUI-native moving highlight using the same placeholder shape.
  case shimmer
  /// A static placeholder.
  case none
}

/// A shape-composable placeholder block shown while content is loading —
/// shadcn's `Skeleton`.
///
///     SCSkeleton(width: 200, height: 20)
///     SCSkeleton(height: 14)                 // flexible width
///     SCSkeleton(width: 48, height: 48, shape: Circle())
public struct SCSkeleton: View {
  @Environment(\.theme) private var theme

  private let width: CGFloat?
  private let height: CGFloat?
  private let cornerRadius: CGFloat?
  private let customShape: AnyShape?
  private let animation: SCSkeletonAnimation
  private let tint: Color?

  /// - Parameters:
  ///   - width: Fixed width, or `nil` to fill the available width.
  ///   - height: Fixed height, or `nil` to accept the caller's frame.
  ///   - cornerRadius: Explicit radius, or the current theme radius when nil.
  ///   - animation: Pulse by default, matching shadcn's `animate-pulse`.
  ///   - tint: Explicit fill, or `theme.muted` when nil.
  public init(
    width: CGFloat? = nil,
    height: CGFloat? = 16,
    cornerRadius: CGFloat? = nil,
    animation: SCSkeletonAnimation = .pulse,
    tint: Color? = nil
  ) {
    self.width = width.map { max($0, 0) }
    self.height = height.map { max($0, 0) }
    self.cornerRadius = cornerRadius.map { max($0, 0) }
    self.customShape = nil
    self.animation = animation
    self.tint = tint
  }

  /// Creates a Skeleton using any caller-provided SwiftUI shape.
  public init<PlaceholderShape: Shape>(
    width: CGFloat? = nil,
    height: CGFloat? = nil,
    shape: PlaceholderShape,
    animation: SCSkeletonAnimation = .pulse,
    tint: Color? = nil
  ) {
    self.width = width.map { max($0, 0) }
    self.height = height.map { max($0, 0) }
    self.cornerRadius = nil
    self.customShape = AnyShape(shape)
    self.animation = animation
    self.tint = tint
  }

  public var body: some View {
    placeholder
      .frame(width: width, height: height)
      .modifier(
        SCSkeletonAnimationModifier(
          animation: animation,
          highlight: theme.background.opacity(0.4)
        )
      )
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var placeholder: some View {
    if let customShape {
      customShape.fill(tint ?? theme.muted)
    } else {
      RoundedRectangle(
        cornerRadius: cornerRadius ?? max(theme.radius / 2, 6),
        style: .continuous
      )
      .fill(tint ?? theme.muted)
    }
  }
}

// MARK: - Modifier

extension View {
  /// Swaps this view for a skeleton placeholder while `condition` is true:
  /// text and images are redacted to placeholder shapes, a shimmer sweeps
  /// across them, and hit testing is disabled. The layout keeps the
  /// content's size, so nothing jumps when loading finishes.
  ///
  ///     VStack(alignment: .leading) {
  ///         Text(article.title).font(.headline)
  ///         Text(article.summary)
  ///     }
  ///     .scSkeleton(when: isLoading)
  public func scSkeleton(
    when condition: Bool,
    animation: SCSkeletonAnimation = .pulse
  ) -> some View {
    modifier(SCSkeletonModifier(isActive: condition, animation: animation))
  }
}

private struct SCSkeletonModifier: ViewModifier {
  @Environment(\.theme) private var theme

  var isActive: Bool
  var animation: SCSkeletonAnimation

  @ViewBuilder
  func body(content: Content) -> some View {
    if isActive {
      content
        .redacted(reason: .placeholder)
        .modifier(
          SCSkeletonAnimationModifier(
            animation: animation,
            highlight: theme.background.opacity(0.4)
          )
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    } else {
      content
    }
  }
}

// MARK: - Shared animation engine

private struct SCSkeletonAnimationModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let animation: SCSkeletonAnimation
  let highlight: Color

  @ViewBuilder
  func body(content: Content) -> some View {
    if reduceMotion || animation == .none {
      content
    } else {
      switch animation {
      case .pulse:
        content.phaseAnimator([false, true]) { content, isDimmed in
          content.opacity(isDimmed ? 0.55 : 1)
        } animation: { _ in
          .easeInOut(duration: 1.2)
        }
      case .shimmer:
        content.overlay {
          SCSkeletonShimmer(highlight: highlight)
            .mask(content)
        }
      case .none:
        content
      }
    }
  }
}

/// A soft highlight band that sweeps left → right forever. Internal to
/// the shared Skeleton animation engine.
private struct SCSkeletonShimmer: View {
  var highlight: Color

  var body: some View {
    GeometryReader { geometry in
      let shimmerWidth = geometry.size.width

      LinearGradient(
        colors: [highlight.opacity(0), highlight, highlight.opacity(0)],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(width: shimmerWidth * 0.6, height: geometry.size.height)
      // Phase -1 parks the band fully off the leading edge; 2 is fully
      // past the trailing edge, so the repeat loops seamlessly.
      .keyframeAnimator(initialValue: CGFloat(-1), repeating: true) { content, phase in
        content.offset(x: phase * shimmerWidth)
      } keyframes: { _ in
        LinearKeyframe(CGFloat(2), duration: 1.6)
      }
    }
    .allowsHitTesting(false)
  }
}
