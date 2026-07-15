// ============================================================
// ScrubBar.swift — swiftcn-ui (Audio)
// Depends on: Theme/
//
// SwiftUI port of elevenlabs-ui's `ScrubBar` compound component:
// a playback scrubbing control with a shared container context,
// a pointer-scrubbable track, a progress fill, a positioned
// thumb, and tabular time labels. Upstream parts:
// ScrubBarContainer · ScrubBarTrack · ScrubBarProgress ·
// ScrubBarThumb · ScrubBarTimeLabel · useScrubBarContext.
//
// Intentional adaptations, in the MessageScroller tradition:
// - `SCScrubBarContext` in the SwiftUI environment replaces the
//   React context and `useScrubBarContext`; parts render nothing
//   outside a container instead of throwing.
// - A `DragGesture` on the track replaces the window pointer
//   capture; `context.progress` is a 0…1 fraction rather than
//   upstream's CSS percentage.
// - `SCScrubBarProgress` composes swiftcn's shared `SCProgress`
//   parts, matching upstream's own Progress dependency. A zero
//   indicator animation duration mirrors upstream's
//   `[&>div]:transition-none` scrub-time override.
// - The track adds a native accessibility adjustable action
//   (±5% seeks) behind upstream's `role="slider"` attributes.
// ============================================================
import SwiftUI

// MARK: - Context

/// What `SCScrubBarContainer` publishes to its parts through the
/// environment — upstream's `ScrubBarContextValue`. Read it from custom
/// parts via `@Environment(\.scScrubBar)`.
public struct SCScrubBarContext {
  /// Total scrubbable duration in seconds.
  public var duration: TimeInterval
  /// Current playback position in seconds.
  public var value: TimeInterval
  /// `value / duration` as a 0…1 fraction (upstream's percentage).
  public var progress: Double
  /// Called with the target time for every scrub movement.
  public var onScrub: (@MainActor (TimeInterval) -> Void)?
  /// Called when a scrub interaction begins.
  public var onScrubStart: (@MainActor () -> Void)?
  /// Called when a scrub interaction ends.
  public var onScrubEnd: (@MainActor () -> Void)?
}

private struct SCScrubBarContextKey: EnvironmentKey {
  static var defaultValue: SCScrubBarContext? { nil }
}

extension EnvironmentValues {
  /// The nearest enclosing `SCScrubBarContainer` context — upstream's
  /// `useScrubBarContext`. `nil` outside a container.
  public var scScrubBar: SCScrubBarContext? {
    get { self[SCScrubBarContextKey.self] }
    set { self[SCScrubBarContextKey.self] = newValue }
  }
}

// MARK: - Container

/// The scrub-bar root — elevenlabs-ui's `ScrubBarContainer`. Lays its
/// parts out in a centered row and shares position, duration, and the
/// scrub callbacks with every part through the environment.
///
///     SCScrubBarContainer(duration: duration, value: position, onScrub: { position = $0 }) {
///         SCScrubBarTimeLabel(time: position)
///         SCScrubBarTrack {
///             SCScrubBarProgress()
///             SCScrubBarThumb()
///         }
///         SCScrubBarTimeLabel(time: duration)
///     }
public struct SCScrubBarContainer<Content: View>: View {
  var duration: TimeInterval
  var value: TimeInterval
  var onScrub: (@MainActor (TimeInterval) -> Void)?
  var onScrubStart: (@MainActor () -> Void)?
  var onScrubEnd: (@MainActor () -> Void)?
  var content: Content

  /// - Parameters:
  ///   - duration: Total scrubbable duration in seconds.
  ///   - value: Current playback position in seconds.
  ///   - onScrub: Called with the target time for every scrub movement.
  ///   - onScrubStart: Called when a scrub interaction begins.
  ///   - onScrubEnd: Called when a scrub interaction ends.
  ///   - content: The compound parts, usually labels around a track.
  public init(
    duration: TimeInterval,
    value: TimeInterval,
    onScrub: (@MainActor (TimeInterval) -> Void)? = nil,
    onScrubStart: (@MainActor () -> Void)? = nil,
    onScrubEnd: (@MainActor () -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.duration = duration
    self.value = value
    self.onScrub = onScrub
    self.onScrubStart = onScrubStart
    self.onScrubEnd = onScrubEnd
    self.content = content()
  }

  public var body: some View {
    HStack(spacing: 0) {
      content
    }
    .frame(maxWidth: .infinity)
    .environment(\.scScrubBar, context)
  }

  private var context: SCScrubBarContext {
    SCScrubBarContext(
      duration: duration,
      value: value,
      progress: duration > 0 ? value / duration : 0,
      onScrub: onScrub,
      onScrubStart: onScrubStart,
      onScrubEnd: onScrubEnd
    )
  }
}

// MARK: - Track

/// The scrubbable rail — upstream's `ScrubBarTrack`. An 8 pt secondary
/// capsule that grows to the available width, hosts the progress and
/// thumb parts, and converts presses and drags into `onScrub` times.
///
///     SCScrubBarTrack {
///         SCScrubBarProgress()
///         SCScrubBarThumb()
///     }
public struct SCScrubBarTrack<Content: View>: View {
  @Environment(\.scScrubBar) private var scrubBar
  @Environment(\.theme) private var theme
  @State private var isScrubbing = false

  var content: Content

  /// - Parameter content: Track overlays, usually progress and thumb.
  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  /// Upstream's `h-2` track height.
  private static var trackHeight: CGFloat { 8 }

  public var body: some View {
    if let context = scrubBar {
      track(context)
    }
  }

  private func track(_ context: SCScrubBarContext) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(theme.secondary)
        content
      }
      .contentShape(Rectangle())
      .gesture(scrubGesture(context, width: geometry.size.width))
    }
    .frame(height: Self.trackHeight)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Playback position")
    .accessibilityValue(accessibilityValueText(context))
    .accessibilityAdjustableAction { direction in
      adjust(context, direction: direction)
    }
  }

  /// Upstream's pointer capture: scrub start on press, a scrub per
  /// movement, and scrub end on release.
  private func scrubGesture(_ context: SCScrubBarContext, width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { gesture in
        guard context.duration > 0, width > 0 else { return }
        if !isScrubbing {
          isScrubbing = true
          context.onScrubStart?()
        }
        context.onScrub?(time(atX: gesture.location.x, width: width, in: context))
      }
      .onEnded { _ in
        guard isScrubbing else { return }
        isScrubbing = false
        context.onScrubEnd?()
      }
  }

  /// Upstream's `getTimeFromClientX`: clamp the pointer ratio to 0…1
  /// and scale by the duration.
  private func time(atX x: CGFloat, width: CGFloat, in context: SCScrubBarContext) -> TimeInterval {
    let ratio = min(max(x / width, 0), 1)
    return context.duration * ratio
  }

  /// The `aria-valuenow`/`aria-valuemax` pair, spoken as times.
  private func accessibilityValueText(_ context: SCScrubBarContext) -> String {
    let clamped = min(max(context.value, 0), max(context.duration, 0))
    let now = SCScrubBarTimeLabel.timestamp(clamped)
    let max = SCScrubBarTimeLabel.timestamp(context.duration)
    return "\(now) of \(max)"
  }

  /// Native slider adjustability over upstream's `role="slider"`.
  private func adjust(_ context: SCScrubBarContext, direction: AccessibilityAdjustmentDirection) {
    guard context.duration > 0 else { return }
    let step = context.duration / 20
    let target = direction == .increment ? context.value + step : context.value - step
    context.onScrub?(min(max(target, 0), context.duration))
  }
}

// MARK: - Progress

/// The played-portion fill — upstream's `ScrubBarProgress`, the shadcn
/// Progress layered inside the track with its transition disabled: a
/// primary/20 rail under a primary fill sized by the context progress.
///
///     SCScrubBarProgress()
public struct SCScrubBarProgress: View {
  @Environment(\.scScrubBar) private var scrubBar
  @Environment(\.theme) private var theme

  public init() {}

  public var body: some View {
    if let context = scrubBar {
      fill(context)
    }
  }

  private func fill(_ context: SCScrubBarContext) -> some View {
    SCProgress(
      value: context.progress,
      minimumValue: 0,
      maximumValue: 1,
      accessibilityLabel: "Playback progress",
      showsDefaultTrack: false
    ) {
      SCProgressTrack(height: 8, tint: theme.primary.opacity(0.2)) {
        SCProgressIndicator(animationDuration: 0)
      }
    }
    .allowsHitTesting(false)
  }
}

// MARK: - Thumb

/// The position marker — upstream's `ScrubBarThumb`. A 16 pt primary
/// circle centered on the progress fraction; custom content renders on
/// top of it.
///
///     SCScrubBarThumb()
public struct SCScrubBarThumb<Content: View>: View {
  @Environment(\.scScrubBar) private var scrubBar
  @Environment(\.theme) private var theme

  var content: Content

  /// - Parameter content: Optional content drawn over the circle.
  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  /// Upstream's `h-4 w-4` thumb diameter.
  private static var diameter: CGFloat { 16 }

  public var body: some View {
    if let context = scrubBar {
      thumb(context)
    }
  }

  private func thumb(_ context: SCScrubBarContext) -> some View {
    GeometryReader { geometry in
      ZStack {
        Circle()
          .fill(theme.primary)
          .frame(width: Self.diameter, height: Self.diameter)
        content
      }
      .position(
        x: geometry.size.width * min(max(context.progress, 0), 1),
        y: geometry.size.height / 2
      )
    }
    .allowsHitTesting(false)
  }
}

extension SCScrubBarThumb where Content == EmptyView {
  /// A plain thumb with no custom content.
  public init() {
    self.init { EmptyView() }
  }
}

// MARK: - Time label

/// A tabular time readout — upstream's `ScrubBarTimeLabel`. Formats the
/// time as `m:ss` unless a custom formatter is supplied.
///
///     SCScrubBarTimeLabel(time: position)
///     SCScrubBarTimeLabel(time: remaining) { "-" + SCScrubBarTimeLabel.timestamp($0) }
public struct SCScrubBarTimeLabel: View {
  var time: TimeInterval
  var format: ((TimeInterval) -> String)?

  /// - Parameters:
  ///   - time: The time to display, in seconds.
  ///   - format: Custom formatter; `nil` uses `m:ss`.
  public init(time: TimeInterval, format: ((TimeInterval) -> String)? = nil) {
    self.time = time
    self.format = format
  }

  public var body: some View {
    Text(format?(time) ?? Self.timestamp(time))
      .monospacedDigit()
  }

  /// Upstream's `formatTimestamp`: `m:ss`, with invalid and negative
  /// values reading `0:00`.
  public static func timestamp(_ value: TimeInterval) -> String {
    guard value.isFinite, value >= 0 else { return "0:00" }
    let totalSeconds = Int(value)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}
