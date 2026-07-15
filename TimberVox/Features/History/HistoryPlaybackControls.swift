import AVFoundation
import Observation
import SwiftUI

@MainActor
@Observable
final class HistoryAudioPlayer: SCTranscriptViewerPlayer {
  enum Availability: Equatable {
    case loading
    case ready
    case unavailable(String)
  }

  private(set) var isPlaying = false
  private(set) var currentTime: TimeInterval = 0
  private(set) var duration: TimeInterval = 0
  private(set) var availability = Availability.loading

  private var audioPlayer: AVAudioPlayer?

  func load(audioPath: String?) async {
    stop()
    availability = .loading

    guard let audioPath else {
      availability = .unavailable("Recording was not saved")
      return
    }
    guard FileManager.default.fileExists(atPath: audioPath) else {
      availability = .unavailable("Recording file is missing")
      return
    }

    do {
      let loadedPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: audioPath))
      loadedPlayer.prepareToPlay()
      audioPlayer = loadedPlayer
      duration = loadedPlayer.duration
      currentTime = 0
      availability = .ready

      while !Task.isCancelled, audioPlayer === loadedPlayer {
        synchronize(with: loadedPlayer)
        try? await Task.sleep(for: .milliseconds(50))
      }
    } catch {
      audioPlayer = nil
      duration = 0
      currentTime = 0
      availability = .unavailable("Recording could not be opened")
    }
  }

  func play() {
    guard let audioPlayer else { return }
    if currentTime >= duration {
      seek(to: 0)
    }
    isPlaying = audioPlayer.play()
  }

  func pause() {
    audioPlayer?.pause()
    isPlaying = false
  }

  func seek(to time: TimeInterval) {
    let target = min(max(time, 0), duration)
    currentTime = target
    audioPlayer?.currentTime = target
  }

  func stop() {
    audioPlayer?.stop()
    audioPlayer = nil
    isPlaying = false
    currentTime = 0
    duration = 0
  }

  private func synchronize(with player: AVAudioPlayer) {
    currentTime = min(max(player.currentTime, 0), duration)
    isPlaying = player.isPlaying
  }
}

struct HistoryPlaybackControls: View {
  let record: TranscriptRecord
  let player: HistoryAudioPlayer
  @Environment(\.theme) private var theme

  var body: some View {
    Group {
      switch player.availability {
      case .loading:
        playbackBar.disabled(true)
      case .ready:
        playbackBar
      case .unavailable(let message):
        unavailableBar(message: message)
      }
    }
    .padding(.horizontal, AppSpacing.md)
    .padding(.vertical, AppSpacing.sm)
    .background(theme.muted.opacity(0.45), in: shape)
    .overlay { shape.strokeBorder(theme.border) }
  }

  private var playbackBar: some View {
    HStack(spacing: AppSpacing.sm) {
      SCTranscriptViewerPlayPauseButton(variant: .ghost, size: .iconXS)
      SCTranscriptViewerScrubBar()
    }
    .font(.system(size: 10, weight: .medium))
    .foregroundStyle(theme.mutedForeground)
  }

  private func unavailableBar(message: String) -> some View {
    HStack(spacing: AppSpacing.sm) {
      Image(systemName: "waveform.slash")
        .foregroundStyle(theme.mutedForeground)

      Text(message)
        .font(.system(size: 11, weight: .medium))

      Spacer(minLength: AppSpacing.sm)

      if record.durationSeconds > 0 {
        SCScrubBarTimeLabel(time: record.durationSeconds)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(theme.mutedForeground)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: max(theme.radius - 2, 4), style: .continuous)
  }
}
