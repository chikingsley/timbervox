// ============================================================
// TranscriptViewerControls.swift — swiftcn-ui (Audio)
// Play/pause and scrub-bar parts for the transcript-viewer
// registry item.
// ============================================================
import SwiftUI

// MARK: - Play/pause button

/// Toggles transcript playback — upstream's
/// `TranscriptViewerPlayPauseButton`. Shows play or pause icons by
/// default; a custom label builder receives the playing state.
///
///     SCTranscriptViewerPlayPauseButton()
///
///     SCTranscriptViewerPlayPauseButton(size: .default) { isPlaying in
///         Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
///     }
public struct SCTranscriptViewerPlayPauseButton<Label: View>: View {
  @Environment(\.scTranscriptViewer) private var transcriptViewer

  var variant: SCButtonVariant
  var size: SCButtonSize
  var action: (() -> Void)?
  var label: ((Bool) -> Label)?

  /// - Parameters:
  ///   - variant: Button variant (outline, as upstream).
  ///   - size: Button size (icon, as upstream).
  ///   - action: Extra handler invoked after toggling (`onClick`).
  ///   - label: Custom label receiving the playing state.
  public init(
    variant: SCButtonVariant = .outline,
    size: SCButtonSize = .icon,
    action: (() -> Void)? = nil,
    @ViewBuilder label: @escaping (Bool) -> Label
  ) {
    self.variant = variant
    self.size = size
    self.action = action
    self.label = label
  }

  public var body: some View {
    if let context = transcriptViewer {
      button(context)
    }
  }

  private func button(_ context: SCTranscriptViewerContext) -> some View {
    Button {
      if context.isPlaying {
        context.pause()
      } else {
        context.play()
      }
      action?()
    } label: {
      if let label {
        label(context.isPlaying)
      } else {
        Image(systemName: context.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 14, weight: .medium))
      }
    }
    .buttonStyle(.sc(variant, size: size))
    .accessibilityLabel(context.isPlaying ? "Pause audio" : "Play audio")
  }
}

extension SCTranscriptViewerPlayPauseButton where Label == EmptyView {
  /// The default play/pause icon button.
  public init(
    variant: SCButtonVariant = .outline,
    size: SCButtonSize = .icon,
    action: (() -> Void)? = nil
  ) {
    self.variant = variant
    self.size = size
    self.action = action
    self.label = nil
  }
}

// MARK: - Scrub bar

/// The context-aware scrub bar — upstream's `TranscriptViewerScrubBar`.
/// Wires the shared `SCScrubBar` parts to the transcript context, with
/// elapsed and remaining time labels underneath.
///
///     SCTranscriptViewerScrubBar()
public struct SCTranscriptViewerScrubBar: View {
  @Environment(\.scTranscriptViewer) private var transcriptViewer
  @Environment(\.theme) private var theme

  var showTimeLabels: Bool
  var trackTint: Color?
  var progressTint: Color?
  var thumbTint: Color?

  /// - Parameter showTimeLabels: Shows elapsed/remaining labels below
  ///   the track.
  public init(
    showTimeLabels: Bool = true,
    trackTint: Color? = nil,
    progressTint: Color? = nil,
    thumbTint: Color? = nil
  ) {
    self.showTimeLabels = showTimeLabels
    self.trackTint = trackTint
    self.progressTint = progressTint
    self.thumbTint = thumbTint
  }

  public var body: some View {
    if let context = transcriptViewer {
      scrubBar(context)
    }
  }

  private func scrubBar(_ context: SCTranscriptViewerContext) -> some View {
    SCScrubBarContainer(
      duration: context.duration,
      value: context.currentTime,
      onScrub: context.seekToTime,
      onScrubStart: context.startScrubbing,
      onScrubEnd: context.endScrubbing
    ) {
      VStack(spacing: 4) {
        SCScrubBarTrack {
          SCScrubBarProgress(trackTint: trackTint, progressTint: progressTint)
          SCScrubBarThumb(tint: thumbTint)
        }
        if showTimeLabels {
          HStack {
            SCScrubBarTimeLabel(time: context.currentTime)
            Spacer()
            SCScrubBarTimeLabel(time: context.duration - context.currentTime)
          }
          .font(.caption)
          .foregroundStyle(theme.mutedForeground)
        }
      }
    }
  }
}
