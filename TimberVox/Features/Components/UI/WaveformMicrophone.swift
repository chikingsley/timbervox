// ============================================================
// WaveformMicrophone.swift — swiftcn-ui (Audio)
// Depends on: Theme/ · Audio/AudioLevelProvider.swift ·
// Audio/Waveform.swift
// Part of the multi-file `waveform` registry item.
//
// SwiftUI port of elevenlabs-ui's `waveform.tsx` microphone-
// driven core: the recording playback seam and `MicrophoneWaveform`
// (live mirrored bands with processing animation and fade-to-idle).
// Live capture history and completed-take views live in sibling files.
//
// Intentional adaptations, in the MessageScroller tradition:
// - `SCAudioLevelProvider` polling replaces the embedded
//   `getUserMedia`/`AnalyserNode` capture; `fftSize`,
//   `smoothingTimeConstant`, and `onError` are engine concerns.
//   `MicrophoneWaveform`'s 5–40 percent bin slice becomes the
//   provider's 22 low-to-high bands mirrored around the center
//   (44 bars — the shape of upstream's default fftSize).
// - `SCWaveformRecordingPlayback` replaces the MediaRecorder +
//   AudioBuffer scrub/playback glue: `enableAudioPlayback` is a
//   `nil` engine, and `playbackRate`, the lowpass scrub filter,
//   and blob decoding live in the conforming engine.
// - Upstream's playback-follow offset math mixes the drag path's
//   sign convention; the port follows playback by panning from
//   the recording start to the live edge (the evident intent)
//   and snaps to the live edge when playback ends.
// - `savedHistoryRef` and `dragOffset`/`setDragOffset` become
//   optional SwiftUI Bindings, adopted on appear and written on
//   recording stop, drag, and playback-follow events.
// - `TimelineView(.animation)` + `Canvas` replace the rAF loops;
//   per-frame animation constants integrate per second (1.8/s,
//   1.2/s — the LiveWaveform precedent) and `updateRate` is in
//   seconds (0.05 ≈ upstream's 50 ms).
// ============================================================
import SwiftUI

// MARK: - Recording playback seam

/// The scrub-audio seam behind `SCLiveMicrophoneWaveform` — the surface
/// of upstream's MediaRecorder/AudioBuffer glue that the component
/// consumes, as an observable protocol. Conform with AVAudioEngine or
/// any player; the engine owns capture, decoding, playback rate, and
/// the lowpass scrub filter. Start and stop recording alongside the
/// waveform's `active` flag.
///
///     @Observable final class TakePlayback: SCWaveformRecordingPlayback {
///         private(set) var duration: TimeInterval = 0
///         private(set) var playbackPosition: TimeInterval?
///         func playScrub(at time: TimeInterval, velocity: Double) { /* 100 ms snippet */ }
///         func play(from time: TimeInterval) { /* full playback */ }
///         func stop() { /* halt everything */ }
///     }
@MainActor
public protocol SCWaveformRecordingPlayback: AnyObject, Observable {
  /// Duration of the recorded take in seconds; `0` before one exists.
  var duration: TimeInterval { get }
  /// The advancing playback position, `nil` while idle or finished.
  var playbackPosition: TimeInterval? { get }
  /// Plays a short snippet at `time` while scrubbing — upstream's
  /// `playScrubSound`. `velocity` is the signed drag speed in points.
  func playScrub(at time: TimeInterval, velocity: Double)
  /// Starts playback at `time`, superseding any scrub snippet —
  /// upstream's `playFromPosition`.
  func play(from time: TimeInterval)
  /// Stops playback and scrub snippets.
  func stop()
}

// MARK: - Microphone waveform

/// A live microphone waveform with mirrored bands — elevenlabs-ui's
/// `MicrophoneWaveform`. While `active`, it polls the injected level
/// provider and mirrors the low bands around the center; while
/// `processing`, it synthesizes a gentle three-wave animation that
/// blends out of the last live frame; idle, it fades the bars away.
///
///     SCMicrophoneWaveform(active: isListening, levels: microphoneLevels)
///
///     SCMicrophoneWaveform(processing: isTranscribing, sensitivity: 1.5)
public struct SCMicrophoneWaveform: View {
  @State private var model = SCMicrophoneWaveformModel()

  var active: Bool
  var processing: Bool
  var levels: (any SCAudioLevelProvider)?
  var sensitivity: Double
  var barWidth: CGFloat
  var barHeight: CGFloat
  var barGap: CGFloat
  var barRadius: CGFloat
  var barColor: Color?
  var fadeEdges: Bool
  var fadeWidth: CGFloat
  var height: CGFloat?

  /// - Parameters:
  ///   - active: Renders live levels from `levels` while true.
  ///   - processing: Plays the synthesized processing animation while
  ///     true (and `active` is false).
  ///   - levels: The audio engine feeding normalized band levels.
  ///   - sensitivity: Multiplier applied to sampled levels.
  ///
  /// The remaining parameters match `SCWaveform`.
  public init(
    active: Bool = false,
    processing: Bool = false,
    levels: (any SCAudioLevelProvider)? = nil,
    sensitivity: Double = 1,
    barWidth: CGFloat = 4,
    barHeight: CGFloat = 4,
    barGap: CGFloat = 2,
    barRadius: CGFloat = 2,
    barColor: Color? = nil,
    fadeEdges: Bool = true,
    fadeWidth: CGFloat = 24,
    height: CGFloat? = 128
  ) {
    self.active = active
    self.processing = processing
    self.levels = levels
    self.sensitivity = sensitivity
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
      SCWaveform(
        data: model.advance(
          to: timeline.date,
          active: active,
          processing: processing,
          levels: levels,
          sensitivity: sensitivity
        ),
        barWidth: barWidth,
        barHeight: barHeight,
        barGap: barGap,
        barRadius: barRadius,
        barColor: barColor,
        fadeEdges: fadeEdges,
        fadeWidth: fadeWidth,
        height: height
      )
    }
  }
}

/// Per-frame microphone waveform state — upstream's data/processing/fade
/// effects as one stepper.
@MainActor
private final class SCMicrophoneWaveformModel {
  private enum Phase {
    case idle
    case active
    case processing
  }

  /// Half the mirrored band count: upstream's default analyser slices
  /// 5–40 percent of 128 bins (45), mirroring half of them (22).
  private static let halfBandCount = 22
  /// Upstream's processing animation bar count.
  private static let processingBarCount = 45

  private var data: [Double] = []
  private var lastActiveData: [Double] = []
  private var fadeBase: [Double] = []
  private var processingTime = 0.0
  private var transitionProgress = 0.0
  private var fadeProgress = 0.0
  private var phase = Phase.idle
  private var lastFrame: Date?

  func advance(
    to date: Date,
    active: Bool,
    processing: Bool,
    levels: (any SCAudioLevelProvider)?,
    sensitivity: Double
  ) -> [Double] {
    let dt = deltaTime(to: date)
    if active {
      enterPhase(.active)
      sample(levels: levels, sensitivity: sensitivity)
    } else if processing {
      if phase != .processing {
        enterPhase(.processing)
      }
      stepProcessing(dt: dt)
    } else {
      enterPhase(.idle)
      stepFadeToIdle(dt: dt)
    }
    return data
  }

  private func deltaTime(to date: Date) -> Double {
    defer { lastFrame = date }
    guard let lastFrame else { return 0 }
    return min(max(date.timeIntervalSince(lastFrame), 0), 0.1)
  }

  private func enterPhase(_ newPhase: Phase) {
    guard phase != newPhase else { return }
    phase = newPhase
    switch newPhase {
    case .processing:
      processingTime = 0
      transitionProgress = 0
    case .active:
      break
    case .idle:
      fadeProgress = 0
      fadeBase = data
    }
  }

  /// Upstream's `updateData`: mirrored low-to-high bands, low bands at
  /// the center.
  private func sample(levels: (any SCAudioLevelProvider)?, sensitivity: Double) {
    guard let levels else { return }
    let bands = levels.levels(bandCount: Self.halfBandCount)
    func value(_ index: Int) -> Double {
      let level = index < bands.count ? Double(bands[index]) : 0
      return min(1, level * sensitivity)
    }
    var mirrored: [Double] = []
    mirrored.reserveCapacity(Self.halfBandCount * 2)
    for index in stride(from: Self.halfBandCount - 1, through: 0, by: -1) {
      mirrored.append(value(index))
    }
    for index in 0..<Self.halfBandCount {
      mirrored.append(value(index))
    }
    data = mirrored
    lastActiveData = mirrored
  }

  /// Upstream's processing animation: three waves under a center
  /// weight, blended out of the last live frame.
  private func stepProcessing(dt: Double) {
    processingTime += 1.8 * dt
    transitionProgress = min(1, transitionProgress + 1.2 * dt)
    let barCount = Self.processingBarCount
    var bars: [Double] = []
    bars.reserveCapacity(barCount)
    for index in 0..<barCount {
      let position = (Double(index) - Double(barCount) / 2) / (Double(barCount) / 2)
      let centerWeight = 1 - abs(position) * 0.4
      let combinedWave =
        sin(processingTime * 1.5 + Double(index) * 0.15) * 0.25
        + sin(processingTime * 0.8 - Double(index) * 0.1) * 0.2
        + cos(processingTime * 2 + Double(index) * 0.05) * 0.15
      var value = (0.2 + combinedWave) * centerWeight
      if !lastActiveData.isEmpty && transitionProgress < 1 {
        let lastIndex = min(
          Int(Double(index) / Double(barCount) * Double(lastActiveData.count)),
          lastActiveData.count - 1
        )
        let lastValue = lastActiveData[lastIndex]
        value = lastValue * (1 - transitionProgress) + value * transitionProgress
      }
      bars.append(max(0.05, min(1, value)))
    }
    data = bars
  }

  /// Upstream's `fadeToIdle`: scale the snapshot taken at fade start
  /// down to nothing.
  private func stepFadeToIdle(dt: Double) {
    guard !data.isEmpty else { return }
    fadeProgress += 1.8 * dt
    if fadeProgress < 1 {
      let factor = 1 - fadeProgress
      data = fadeBase.map { $0 * factor }
    } else {
      data = []
      fadeBase = []
    }
  }
}
