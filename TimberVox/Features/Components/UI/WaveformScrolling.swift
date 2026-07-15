// ============================================================
// WaveformScrolling.swift — swiftcn-ui (Audio)
// Continuously scrolling waveform for the waveform registry item.
// ============================================================
import SwiftUI

// MARK: - Scrolling waveform

/// An endlessly scrolling waveform — elevenlabs-ui's `ScrollingWaveform`.
/// Bars drift toward the leading edge at `speed` points per second while
/// new bars spawn at the trailing edge, cycling through `data` when
/// provided and synthesizing wave-plus-noise heights otherwise.
///
///     SCScrollingWaveform(speed: 30, height: 80)
///
///     SCScrollingWaveform(data: amplitudes)
public struct SCScrollingWaveform: View {
  @Environment(\.theme) private var theme
  @State private var model = SCScrollingWaveformModel()

  var speed: Double
  var barCount: Int
  var data: [Double]
  var barWidth: CGFloat
  var barHeight: CGFloat
  var barGap: CGFloat
  var barRadius: CGFloat
  var barColor: Color?
  var fadeEdges: Bool
  var fadeWidth: CGFloat
  var height: CGFloat?

  /// - Parameters:
  ///   - speed: Scroll speed in points per second.
  ///   - barCount: Safety cap on spawned bars (twice this count).
  ///   - data: Amplitudes to cycle through; empty synthesizes heights.
  ///
  /// The remaining parameters match `SCWaveform`.
  public init(
    speed: Double = 50,
    barCount: Int = 60,
    data: [Double] = [],
    barWidth: CGFloat = 4,
    barHeight: CGFloat = 4,
    barGap: CGFloat = 2,
    barRadius: CGFloat = 2,
    barColor: Color? = nil,
    fadeEdges: Bool = true,
    fadeWidth: CGFloat = 24,
    height: CGFloat? = 128
  ) {
    self.speed = speed
    self.barCount = barCount
    self.data = data
    self.barWidth = barWidth
    self.barHeight = barHeight
    self.barGap = barGap
    self.barRadius = barRadius
    self.barColor = barColor
    self.fadeEdges = fadeEdges
    self.fadeWidth = fadeWidth
    self.height = height
  }

  public var body: some View {
    TimelineView(.animation) { timeline in
      Canvas { context, size in
        let renderer = SCWaveformRenderer(
          barWidth: barWidth,
          barHeight: barHeight,
          barGap: barGap,
          barRadius: barRadius,
          color: barColor ?? theme.foreground,
          heightScale: 0.6,
          fadeEdges: fadeEdges,
          fadeWidth: fadeWidth
        )
        let bars = model.advance(to: timeline.date, width: size.width, using: configuration)
        for bar in bars where bar.x < size.width && bar.x + barWidth > 0 {
          renderer.drawBar(value: bar.height, atX: bar.x, in: &context, size: size)
        }
        renderer.eraseEdges(in: &context, size: size)
      }
    }
    .frame(height: height)
    .frame(maxWidth: .infinity)
  }

  private var configuration: SCScrollingWaveformModel.Configuration {
    SCScrollingWaveformModel.Configuration(
      speed: speed,
      barCount: barCount,
      data: data,
      barWidth: barWidth,
      barGap: barGap
    )
  }
}

/// Per-frame scrolling state, mutated inside the `Canvas` renderer the
/// way upstream mutates its refs inside requestAnimationFrame.
@MainActor
private final class SCScrollingWaveformModel {
  struct Configuration {
    var speed: Double
    var barCount: Int
    var data: [Double]
    var barWidth: CGFloat
    var barGap: CGFloat
  }

  struct Bar {
    var x: CGFloat
    var height: Double
  }

  /// Deterministic stand-in for upstream's per-mount `Math.random()` seed.
  private let seed = 0.4242
  private var bars: [Bar] = []
  private var lastFrame: Date?
  private var dataIndex = 0

  func advance(to date: Date, width: CGFloat, using configuration: Configuration) -> [Bar] {
    let dt = deltaTime(to: date)
    let step = configuration.barWidth + configuration.barGap
    guard step > 0, width > 0 else { return bars }
    if bars.isEmpty {
      seedInitialBars(width: width, step: step)
    }
    for index in bars.indices {
      bars[index].x -= configuration.speed * dt
    }
    bars.removeAll { $0.x + configuration.barWidth <= -step }
    while bars.isEmpty || (bars.last?.x ?? 0) < width {
      let nextX = bars.last.map { $0.x + step } ?? width
      bars.append(Bar(x: nextX, height: nextHeight(at: date, using: configuration)))
      if bars.count > configuration.barCount * 2 { break }
    }
    return bars
  }

  private func deltaTime(to date: Date) -> Double {
    defer { lastFrame = date }
    guard let lastFrame else { return 0 }
    return min(max(date.timeIntervalSince(lastFrame), 0), 0.1)
  }

  /// Upstream's ResizeObserver seeding: a full row of 0.2–0.8 bars.
  private func seedInitialBars(width: CGFloat, step: CGFloat) {
    var currentX = width
    var index = 0
    var seeded: [Bar] = []
    while currentX > -step {
      seeded.append(Bar(x: currentX, height: 0.2 + scWaveformSeededRandom(seed * 10000 + Double(index)) * 0.6))
      currentX -= step
      index += 1
    }
    bars = seeded.reversed()
  }

  /// The next spawned height: cycled data, or upstream's two-wave plus
  /// seeded-noise synthesis.
  private func nextHeight(at date: Date, using configuration: Configuration) -> Double {
    if !configuration.data.isEmpty {
      let data = configuration.data
      let value = data[dataIndex % data.count]
      dataIndex = (dataIndex + 1) % data.count
      return value == 0 ? 0.1 : value
    }
    let time = date.timeIntervalSince1970
    let uniqueIndex = Double(bars.count) + time * 0.01
    let wave1 = sin(uniqueIndex * 0.1) * 0.2
    let wave2 = cos(uniqueIndex * 0.05) * 0.15
    let random = scWaveformSeededRandom(seed * 10000 + uniqueIndex * 137.5) * 0.4
    return max(0.1, min(0.9, 0.3 + wave1 + wave2 + random))
  }
}
