// ============================================================
// Waveform.swift — swiftcn-ui (Audio)
// Depends on: Theme/
// Part of the multi-file `waveform` registry item.
//
// SwiftUI port of elevenlabs-ui's `waveform.tsx` data-driven
// core: `Waveform` (amplitude bars from a data array with
// bar-click mapping) and `StaticWaveform` (seeded random bars).
// Scrolling, scrubber, microphone, and recording parts live in
// sibling Waveform*.swift files in the same registry item.
//
// Intentional adaptations, in the MessageScroller tradition:
// - `TimelineView(.animation)` + `Canvas` replace the canvas
//   requestAnimationFrame loops; drawing (bar geometry, the
//   0.3–1.0 level alpha, the destination-out edge fade capped
//   at 20 percent per side) is 1:1.
// - Deterministic seeded noise replaces `Math.random()` (the
//   BarVisualizer precedent): `ScrollingWaveform`'s per-mount
//   random seed becomes a constant, and `AudioScrubber`'s
//   per-render random fallback data becomes a stable seeded
//   array.
// - `ScrollingWaveform`'s initial seeded row is stored in scroll
//   order so appended bars continue from the trailing edge;
//   upstream's descending initial buffer converges to the same
//   steady state after the first spawn cycle.
// - A `DragGesture` replaces the document mouse capture in
//   `AudioScrubber`; the port omits upstream's handle
//   hover-scale rule, which cannot fire through its own
//   `pointer-events-none`. A native accessibility adjustable
//   action (±5% seeks) backs the `role="slider"` attributes.
// - `theme.foreground` replaces the CSS `--foreground` default
//   for `barColor`; `height` is a fixed point value (`nil`
//   fills the proposal, upstream's CSS string heights).
// ============================================================
import SwiftUI

// MARK: - Shared drawing

/// Upstream's fractional hash noise: `sin(x) * 10000`, fractional part.
nonisolated func scWaveformSeededRandom(_ seed: Double) -> Double {
  let value = sin(seed) * 10000
  return value - value.rounded(.down)
}

/// Shared canvas bar drawing for the waveform family — one bar geometry,
/// the 0.3–1.0 level alpha, and the destination-out edge fade that
/// upstream repeats in every renderer.
struct SCWaveformRenderer {
  var barWidth: CGFloat
  var barHeight: CGFloat
  var barGap: CGFloat
  var barRadius: CGFloat
  var color: Color
  /// Bar height as a fraction of the container (0.8 static, 0.6
  /// scrolling, 0.7 recording — upstream's per-component constants).
  var heightScale: Double
  var fadeEdges: Bool
  var fadeWidth: CGFloat

  var step: CGFloat { barWidth + barGap }

  func drawBar(value: Double, atX x: CGFloat, in context: inout GraphicsContext, size: CGSize) {
    let renderedHeight = max(barHeight, value * size.height * heightScale)
    let rect = CGRect(
      x: x,
      y: size.height / 2 - renderedHeight / 2,
      width: barWidth,
      height: renderedHeight
    )
    let alpha = 0.3 + value * 0.7
    let path =
      barRadius > 0
      ? Path(roundedRect: rect, cornerRadius: barRadius, style: .continuous)
      : Path(rect)
    context.fill(path, with: .color(color.opacity(alpha)))
  }

  /// Upstream's destination-out edge gradient, capped at 20 percent of
  /// the width per side.
  func eraseEdges(in context: inout GraphicsContext, size: CGSize) {
    guard fadeEdges, fadeWidth > 0, size.width > 0 else { return }
    let fadeFraction = min(0.2, fadeWidth / size.width)
    let gradient = Gradient(stops: [
      .init(color: .white, location: 0),
      .init(color: .white.opacity(0), location: fadeFraction),
      .init(color: .white.opacity(0), location: 1 - fadeFraction),
      .init(color: .white, location: 1),
    ])
    context.blendMode = .destinationOut
    context.fill(
      Path(CGRect(origin: .zero, size: size)),
      with: .linearGradient(
        gradient,
        startPoint: CGPoint(x: 0, y: size.height / 2),
        endPoint: CGPoint(x: size.width, y: size.height / 2)
      )
    )
    context.blendMode = .normal
  }
}

// MARK: - Waveform

/// A static amplitude waveform for prerecorded audio — elevenlabs-ui's
/// `Waveform`. Renders normalized 0…1 values as centered bars, resampling
/// the data to the bars that fit, with optional edge fading and per-bar
/// click mapping.
///
///     SCWaveform(data: amplitudes)
///
///     SCWaveform(data: amplitudes, height: 100) { index, value in
///         seek(to: Double(index) / Double(amplitudes.count) * duration)
///     }
public struct SCWaveform: View {
  @Environment(\.theme) private var theme

  var data: [Double]
  var barWidth: CGFloat
  var barHeight: CGFloat
  var barGap: CGFloat
  var barRadius: CGFloat
  var barColor: Color?
  var fadeEdges: Bool
  var fadeWidth: CGFloat
  var height: CGFloat?
  var onBarClick: ((Int, Double) -> Void)?

  /// - Parameters:
  ///   - data: Normalized 0…1 amplitudes, resampled across the width.
  ///   - barWidth: Width of each bar in points.
  ///   - barHeight: Minimum bar height in points.
  ///   - barGap: Gap between bars in points.
  ///   - barRadius: Bar corner radius in points.
  ///   - barColor: Bar color; `nil` uses the theme foreground.
  ///   - fadeEdges: Fades the waveform out toward both edges.
  ///   - fadeWidth: Width of each edge fade in points.
  ///   - height: Fixed waveform height; `nil` fills the proposed height.
  ///   - onBarClick: Called with the data index and value of a tapped bar.
  public init(
    data: [Double] = [],
    barWidth: CGFloat = 4,
    barHeight: CGFloat = 4,
    barGap: CGFloat = 2,
    barRadius: CGFloat = 2,
    barColor: Color? = nil,
    fadeEdges: Bool = true,
    fadeWidth: CGFloat = 24,
    height: CGFloat? = 128,
    onBarClick: ((Int, Double) -> Void)? = nil
  ) {
    self.data = data
    self.barWidth = barWidth
    self.barHeight = barHeight
    self.barGap = barGap
    self.barRadius = barRadius
    self.barColor = barColor
    self.fadeEdges = fadeEdges
    self.fadeWidth = fadeWidth
    self.height = height
    self.onBarClick = onBarClick
  }

  public var body: some View {
    GeometryReader { geometry in
      Canvas { context, size in
        draw(in: &context, size: size)
      }
      .contentShape(Rectangle())
      .gesture(
        tapGesture(width: geometry.size.width),
        including: onBarClick == nil ? .none : .all
      )
    }
    .frame(height: height)
    .frame(maxWidth: .infinity)
  }

  private var renderer: SCWaveformRenderer {
    SCWaveformRenderer(
      barWidth: barWidth,
      barHeight: barHeight,
      barGap: barGap,
      barRadius: barRadius,
      color: barColor ?? theme.foreground,
      heightScale: 0.8,
      fadeEdges: fadeEdges,
      fadeWidth: fadeWidth
    )
  }

  private func draw(in context: inout GraphicsContext, size: CGSize) {
    let renderer = renderer
    let barCount = Int(size.width / renderer.step)
    guard barCount > 0 else { return }
    for index in 0..<barCount {
      let dataIndex = Int(Double(index) / Double(barCount) * Double(data.count))
      let value = dataIndex < data.count ? data[dataIndex] : 0
      renderer.drawBar(value: value, atX: CGFloat(index) * renderer.step, in: &context, size: size)
    }
    renderer.eraseEdges(in: &context, size: size)
  }

  /// Upstream's `handleClick`: bar index from the tap, mapped back to
  /// the data index it was resampled from.
  private func tapGesture(width: CGFloat) -> some Gesture {
    SpatialTapGesture()
      .onEnded { gesture in
        guard let onBarClick, !data.isEmpty else { return }
        let step = barWidth + barGap
        let barCount = Int(width / step)
        guard barCount > 0 else { return }
        let barIndex = Int(gesture.location.x / step)
        let dataIndex = barIndex * data.count / barCount
        if dataIndex >= 0 && dataIndex < data.count {
          onBarClick(dataIndex, data[dataIndex])
        }
      }
  }
}

// MARK: - Static waveform

/// A reproducible placeholder waveform — elevenlabs-ui's `StaticWaveform`.
/// Generates `bars` seeded pseudo-random amplitudes (0.2–0.8) and renders
/// them through `SCWaveform`.
///
///     SCStaticWaveform(bars: 40, seed: 42)
public struct SCStaticWaveform: View {
  var bars: Int
  var seed: Double
  var barWidth: CGFloat
  var barHeight: CGFloat
  var barGap: CGFloat
  var barRadius: CGFloat
  var barColor: Color?
  var fadeEdges: Bool
  var fadeWidth: CGFloat
  var height: CGFloat?
  var onBarClick: ((Int, Double) -> Void)?

  /// - Parameters:
  ///   - bars: Number of generated amplitudes.
  ///   - seed: Seed for the deterministic noise.
  ///   - onBarClick: Called with the data index and value of a tapped bar.
  ///
  /// The remaining parameters pass through to `SCWaveform`.
  public init(
    bars: Int = 40,
    seed: Double = 42,
    barWidth: CGFloat = 4,
    barHeight: CGFloat = 4,
    barGap: CGFloat = 2,
    barRadius: CGFloat = 2,
    barColor: Color? = nil,
    fadeEdges: Bool = true,
    fadeWidth: CGFloat = 24,
    height: CGFloat? = 128,
    onBarClick: ((Int, Double) -> Void)? = nil
  ) {
    self.bars = bars
    self.seed = seed
    self.barWidth = barWidth
    self.barHeight = barHeight
    self.barGap = barGap
    self.barRadius = barRadius
    self.barColor = barColor
    self.fadeEdges = fadeEdges
    self.fadeWidth = fadeWidth
    self.height = height
    self.onBarClick = onBarClick
  }

  public var body: some View {
    SCWaveform(
      data: (0..<max(bars, 0)).map { 0.2 + scWaveformSeededRandom(seed + Double($0)) * 0.6 },
      barWidth: barWidth,
      barHeight: barHeight,
      barGap: barGap,
      barRadius: barRadius,
      barColor: barColor,
      fadeEdges: fadeEdges,
      fadeWidth: fadeWidth,
      height: height,
      onBarClick: onBarClick
    )
  }
}
