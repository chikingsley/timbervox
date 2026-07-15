// ============================================================
// WaveformScrubber.swift — swiftcn-ui (Audio)
// Seekable audio scrubber for the waveform registry item.
// ============================================================
import SwiftUI

// MARK: - Audio scrubber

/// A seekable waveform — elevenlabs-ui's `AudioScrubber`. Layers a
/// primary progress tint, a playhead line, and an optional round handle
/// over an `SCWaveform`, converting presses and drags into `onSeek`
/// times.
///
///     SCAudioScrubber(
///         data: amplitudes,
///         currentTime: player.currentTime,
///         duration: player.duration,
///         onSeek: { player.seek(to: $0) }
///     )
public struct SCAudioScrubber: View {
  @Environment(\.theme) private var theme
  @State private var isDragging = false
  @State private var localProgress: Double = 0

  var data: [Double]
  var currentTime: TimeInterval
  var duration: TimeInterval
  var onSeek: ((TimeInterval) -> Void)?
  var showHandle: Bool
  var barWidth: CGFloat
  var barHeight: CGFloat
  var barGap: CGFloat
  var barRadius: CGFloat
  var barColor: Color?
  var height: CGFloat?

  /// Upstream's fallback bars when no data is provided, made stable.
  private static let fallbackData: [Double] = (0..<100).map {
    0.2 + scWaveformSeededRandom(Double($0) * 1.618 + 7) * 0.6
  }

  /// - Parameters:
  ///   - data: Normalized 0…1 amplitudes; empty uses placeholder bars.
  ///   - currentTime: Playback position in seconds.
  ///   - duration: Total duration in seconds.
  ///   - onSeek: Called with the target time for taps and drags.
  ///   - showHandle: Shows the round handle at the playhead.
  ///
  /// The remaining parameters match `SCWaveform`.
  public init(
    data: [Double] = [],
    currentTime: TimeInterval = 0,
    duration: TimeInterval = 100,
    onSeek: ((TimeInterval) -> Void)? = nil,
    showHandle: Bool = true,
    barWidth: CGFloat = 3,
    barHeight: CGFloat = 4,
    barGap: CGFloat = 1,
    barRadius: CGFloat = 1,
    barColor: Color? = nil,
    height: CGFloat? = 128
  ) {
    self.data = data
    self.currentTime = currentTime
    self.duration = duration
    self.onSeek = onSeek
    self.showHandle = showHandle
    self.barWidth = barWidth
    self.barHeight = barHeight
    self.barGap = barGap
    self.barRadius = barRadius
    self.barColor = barColor
    self.height = height
  }

  public var body: some View {
    GeometryReader { geometry in
      scrubber(size: geometry.size)
    }
    .frame(height: height)
    .frame(maxWidth: .infinity)
    .onChange(of: currentTime, initial: true) { syncProgress() }
    .onChange(of: duration) { syncProgress() }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Audio waveform scrubber")
    .accessibilityValue(accessibilityValueText)
    .accessibilityAdjustableAction(adjust)
  }

  private func scrubber(size: CGSize) -> some View {
    let progressX = size.width * min(max(localProgress, 0), 1)
    return ZStack(alignment: .topLeading) {
      SCWaveform(
        data: data.isEmpty ? Self.fallbackData : data,
        barWidth: barWidth,
        barHeight: barHeight,
        barGap: barGap,
        barRadius: barRadius,
        barColor: barColor,
        fadeEdges: false,
        height: nil
      )
      Rectangle()
        .fill(theme.primary.opacity(0.2))
        .frame(width: progressX)
        .frame(maxHeight: .infinity)
        .allowsHitTesting(false)
      Rectangle()
        .fill(theme.primary)
        .frame(width: 2)
        .frame(maxHeight: .infinity)
        .offset(x: progressX)
        .allowsHitTesting(false)
      if showHandle {
        handle.position(x: progressX, y: size.height / 2)
      }
    }
    .contentShape(Rectangle())
    .gesture(scrubGesture(width: size.width))
  }

  /// Upstream's handle: a 16 pt primary circle with a 2 pt background
  /// ring and a soft shadow, inert to pointer events.
  private var handle: some View {
    Circle()
      .fill(theme.primary)
      .overlay(Circle().strokeBorder(theme.background, lineWidth: 2))
      .frame(width: 16, height: 16)
      .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
      .allowsHitTesting(false)
  }

  private func scrubGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { gesture in
        isDragging = true
        scrub(atX: gesture.location.x, width: width)
      }
      .onEnded { _ in
        isDragging = false
      }
  }

  /// Upstream's `handleScrub`: clamp, update the local progress, seek.
  private func scrub(atX x: CGFloat, width: CGFloat) {
    guard width > 0 else { return }
    let progress = min(max(x / width, 0), 1)
    localProgress = progress
    onSeek?(progress * duration)
  }

  /// Upstream keeps the visual progress in sync with `currentTime`
  /// whenever a drag is not in flight.
  private func syncProgress() {
    if !isDragging && duration > 0 {
      localProgress = currentTime / duration
    }
  }

  private var accessibilityValueText: String {
    let now = SCScrubBarTimeLabel.timestamp(min(max(currentTime, 0), max(duration, 0)))
    return "\(now) of \(SCScrubBarTimeLabel.timestamp(duration))"
  }

  /// Native slider adjustability over upstream's `role="slider"`.
  private func adjust(_ direction: AccessibilityAdjustmentDirection) {
    guard duration > 0 else { return }
    let step = duration / 20
    let target = direction == .increment ? currentTime + step : currentTime - step
    onSeek?(min(max(target, 0), duration))
  }
}
