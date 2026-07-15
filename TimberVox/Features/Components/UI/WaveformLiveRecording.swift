// ============================================================
// WaveformLiveRecording.swift — swiftcn-ui (Audio)
// Live capture-history waveform for the waveform registry item.
// ============================================================
import SwiftUI

// MARK: - Live microphone waveform

/// A voice-memo style capture waveform — elevenlabs-ui's
/// `LiveMicrophoneWaveform`. While `active`, averaged levels scroll in
/// from the trailing edge into a capped history; once stopped, the
/// history becomes drag-scrubbable, optionally playing scrub audio and
/// resuming playback through the injected engine.
///
///     SCLiveMicrophoneWaveform(active: isRecording, levels: microphoneLevels)
///
///     SCLiveMicrophoneWaveform(
///         active: isRecording,
///         levels: microphoneLevels,
///         playback: takePlayback,
///         historySize: 300
///     )
public struct SCLiveMicrophoneWaveform: View {
  @Environment(\.theme) private var theme
  @State private var model = SCLiveMicrophoneWaveformModel()
  @State private var isDragging = false
  @State private var dragStartOffset: CGFloat = 0
  @State private var lastScrubTime = Date.distantPast
  @State private var lastDragX: CGFloat = 0

  var active: Bool
  var levels: (any SCAudioLevelProvider)?
  var sensitivity: Double
  var historySize: Int
  var updateRate: TimeInterval
  var playback: (any SCWaveformRecordingPlayback)?
  var history: Binding<[Double]>?
  var dragOffset: Binding<CGFloat>?
  var barWidth: CGFloat
  var barHeight: CGFloat
  var barGap: CGFloat
  var barRadius: CGFloat
  var barColor: Color?
  var fadeEdges: Bool
  var fadeWidth: CGFloat
  var height: CGFloat?

  /// - Parameters:
  ///   - active: Captures levels from `levels` while true.
  ///   - levels: The audio engine feeding normalized levels.
  ///   - sensitivity: Multiplier applied to sampled levels.
  ///   - historySize: Samples kept in the scrollable history.
  ///   - updateRate: Seconds between samples (0.05 ≈ upstream's 50 ms).
  ///   - playback: Scrub-audio engine; `nil` disables audio playback
  ///     (upstream's `enableAudioPlayback: false`).
  ///   - history: External storage for the capture history (upstream's
  ///     `savedHistoryRef`), adopted on appear and written on stop.
  ///   - dragOffset: External scrub offset (upstream's `dragOffset`/
  ///     `setDragOffset`).
  ///
  /// The remaining parameters match `SCWaveform`.
  public init(
    active: Bool = false,
    levels: (any SCAudioLevelProvider)? = nil,
    sensitivity: Double = 1,
    historySize: Int = 150,
    updateRate: TimeInterval = 0.05,
    playback: (any SCWaveformRecordingPlayback)? = nil,
    history: Binding<[Double]>? = nil,
    dragOffset: Binding<CGFloat>? = nil,
    barWidth: CGFloat = 3,
    barHeight: CGFloat = 4,
    barGap: CGFloat = 1,
    barRadius: CGFloat = 1,
    barColor: Color? = nil,
    fadeEdges: Bool = true,
    fadeWidth: CGFloat = 24,
    height: CGFloat? = 128
  ) {
    self.active = active
    self.levels = levels
    self.sensitivity = sensitivity
    self.historySize = historySize
    self.updateRate = updateRate
    self.playback = playback
    self.history = history
    self.dragOffset = dragOffset
    self.barWidth = barWidth
    self.barHeight = barHeight
    self.barGap = barGap
    self.barRadius = barRadius
    self.barColor = barColor
    self.fadeEdges = fadeEdges
    self.fadeWidth = fadeWidth
    self.height = height
  }

  private var step: CGFloat { barWidth + barGap }

  public var body: some View {
    GeometryReader { geometry in
      waveform(width: geometry.size.width)
    }
    .frame(height: height)
    .frame(maxWidth: .infinity)
    .onAppear {
      if let history {
        model.history = history.wrappedValue
      }
      if let dragOffset {
        model.dragOffset = dragOffset.wrappedValue
      }
    }
    .onChange(of: active) { _, isActive in
      if isActive {
        model.history = []
        setOffset(0)
      }
      history?.wrappedValue = model.history
    }
  }

  private func waveform(width: CGFloat) -> some View {
    let scrubbable = !active && !model.history.isEmpty
    return TimelineView(.animation) { timeline in
      Canvas { context, size in
        draw(in: &context, size: size, date: timeline.date)
      }
    }
    .contentShape(Rectangle())
    .gesture(scrubGesture(width: width), including: scrubbable ? .all : .none)
    .onChange(of: playback?.playbackPosition) { previous, position in
      guard !active else { return }
      if let position {
        followPlayback(position, width: width)
      } else if previous != nil {
        setOffset(0)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(scrubbable ? "Drag to scrub through recording" : "Live audio waveform")
    .accessibilityValue(scrubbable ? "\(offsetBars) of \(model.history.count) samples back" : "")
    .accessibilityAdjustableAction { direction in
      adjust(direction, width: width)
    }
  }

  private var offsetBars: Int {
    Int(model.dragOffset / step)
  }

  // MARK: Drawing

  private func draw(in context: inout GraphicsContext, size: CGSize, date: Date) {
    model.sampleIfDue(
      at: date,
      active: active,
      configuration: .init(
        levels: levels,
        sensitivity: sensitivity,
        historySize: historySize,
        updateRate: updateRate
      )
    )
    let renderer = SCWaveformRenderer(
      barWidth: barWidth,
      barHeight: barHeight,
      barGap: barGap,
      barRadius: barRadius,
      color: barColor ?? theme.foreground,
      heightScale: 0.7,
      fadeEdges: fadeEdges,
      fadeWidth: fadeWidth
    )
    let data = model.history
    if !data.isEmpty {
      let barCount = Int(size.width / step)
      let offsetInBars = offsetBars
      for index in 0..<barCount {
        let dataIndex =
          active
          ? data.count - 1 - index
          : min(max(data.count - 1 - index - offsetInBars, 0), data.count - 1)
        guard dataIndex >= 0 && dataIndex < data.count else { continue }
        let x = size.width - CGFloat(index + 1) * step
        renderer.drawBar(value: data[dataIndex], atX: x, in: &context, size: size)
      }
    }
    renderer.eraseEdges(in: &context, size: size)
  }

  // MARK: Scrubbing

  private func scrubGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { gesture in
        if !isDragging {
          isDragging = true
          dragStartOffset = model.dragOffset
          lastDragX = gesture.location.x
          lastScrubTime = .distantPast
        }
        dragMoved(gesture, width: width)
      }
      .onEnded { _ in
        isDragging = false
        dragEnded()
      }
  }

  /// Upstream's mouse-move handler: half-sensitivity offset panning
  /// with a 50 ms throttled scrub sound.
  private func dragMoved(_ gesture: DragGesture.Value, width: CGFloat) {
    let newOffset = dragStartOffset - gesture.translation.width * 0.5
    setOffset(min(max(newOffset, 0), maxOffset(width: width)))

    guard let playback, playback.duration > 0 else { return }
    let now = Date()
    if now.timeIntervalSince(lastScrubTime) > 0.05 {
      lastScrubTime = now
      let velocity = Double(gesture.location.x - lastDragX)
      lastDragX = gesture.location.x
      let position = audioPosition(duration: playback.duration)
      playback.playScrub(at: min(max(position, 0), playback.duration - 0.1), velocity: velocity)
    }
  }

  /// Upstream's mouse-up handler: resume playback at the scrub point.
  private func dragEnded() {
    guard let playback, playback.duration > 0 else { return }
    let position = audioPosition(duration: playback.duration)
    playback.play(from: min(max(position, 0), playback.duration - 0.1))
  }

  /// Maps the current offset back to a take position — upstream's
  /// rightmost-bar-to-duration math.
  private func audioPosition(duration: TimeInterval) -> TimeInterval {
    let maxBars = model.history.count
    guard maxBars > 0 else { return 0 }
    let rightmostBarIndex = min(max(maxBars - 1 - offsetBars, 0), maxBars - 1)
    return Double(rightmostBarIndex) / Double(maxBars) * duration
  }

  private func maxOffset(width: CGFloat) -> CGFloat {
    let viewBars = Int(width / step)
    return max(0, CGFloat(model.history.count - viewBars) * step)
  }

  /// Pans from the recording start to the live edge as playback
  /// advances.
  private func followPlayback(_ position: TimeInterval, width: CGFloat) {
    guard let playback, playback.duration > 0 else { return }
    let count = model.history.count
    guard count > 0 else { return }
    let currentBarIndex = Int(position / playback.duration * Double(count))
    let target = CGFloat(count - 1 - currentBarIndex) * step
    setOffset(min(max(target, 0), maxOffset(width: width)))
  }

  private func setOffset(_ offset: CGFloat) {
    model.dragOffset = offset
    dragOffset?.wrappedValue = offset
  }

  private func adjust(_ direction: AccessibilityAdjustmentDirection, width: CGFloat) {
    guard !active && !model.history.isEmpty else { return }
    let delta = step * 10
    let target = direction == .increment ? model.dragOffset - delta : model.dragOffset + delta
    setOffset(min(max(target, 0), maxOffset(width: width)))
  }
}

/// Reference-typed capture history and scrub offset, mutated inside the
/// `Canvas` renderer the way upstream mutates its refs.
@MainActor
private final class SCLiveMicrophoneWaveformModel {
  struct SamplingConfiguration {
    var levels: (any SCAudioLevelProvider)?
    var sensitivity: Double
    var historySize: Int
    var updateRate: TimeInterval
  }

  var history: [Double] = []
  var dragOffset: CGFloat = 0
  private var lastSample = Date.distantPast

  func sampleIfDue(
    at date: Date,
    active: Bool,
    configuration: SamplingConfiguration
  ) {
    guard
      active,
      let levels = configuration.levels,
      date.timeIntervalSince(lastSample) >= configuration.updateRate
    else { return }
    lastSample = date
    let average = Double(levels.levels(bandCount: 1).first ?? 0) * configuration.sensitivity
    history.append(min(1, max(0.05, average)))
    if history.count > configuration.historySize {
      history.removeFirst(history.count - configuration.historySize)
    }
  }
}
