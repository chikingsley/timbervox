// ============================================================
// TranscriptViewer.swift — swiftcn-ui (Audio)
// Container, word views, and inline flow layout for the
// transcript-viewer registry item.
// ============================================================
import SwiftUI

// MARK: - Container

/// A time-synced transcript viewer — elevenlabs-ui's
/// `TranscriptViewerContainer`. Composes alignment data into words,
/// tracks the current word against the injected player's clock, and
/// shares everything with its parts through the environment.
///
///     SCTranscriptViewerContainer(player: narrationPlayer, alignment: alignment) {
///         SCTranscriptViewerWords()
///         SCTranscriptViewerScrubBar()
///         SCTranscriptViewerPlayPauseButton()
///     }
public struct SCTranscriptViewerContainer<Content: View>: View {
  @State private var isScrubbing = false

  var player: any SCTranscriptViewerPlayer
  var alignment: SCTranscriptAlignment?
  var hideAudioTags: Bool
  var contentSpacing: CGFloat
  var contentInsets: EdgeInsets
  var segmentComposer: ((SCTranscriptAlignment) -> SCTranscriptComposition)?
  var onPlay: (() -> Void)?
  var onPause: (() -> Void)?
  var onTimeUpdate: ((TimeInterval) -> Void)?
  var onEnded: (() -> Void)?
  var onDurationChange: ((TimeInterval) -> Void)?
  var content: Content

  private let composition: SCTranscriptComposition

  /// - Parameters:
  ///   - player: The playback engine (upstream's audio element).
  ///   - alignment: Character-level timing for the narration.
  ///   - hideAudioTags: Removes bracketed audio tags such as `[laughs]`.
  ///   - contentSpacing: Vertical spacing between compound parts.
  ///   - contentInsets: Padding around the compound parts.
  ///   - segmentComposer: Custom alignment-to-segments composer; `nil`
  ///     uses `SCTranscriptComposition.compose`.
  ///   - onPlay: Called when playback starts.
  ///   - onPause: Called when playback pauses before the end.
  ///   - onTimeUpdate: Called as the playback position changes.
  ///   - onEnded: Called when playback stops at the end.
  ///   - onDurationChange: Called when the player learns its duration.
  ///   - content: The compound parts, usually words + scrub bar + button.
  public init(
    player: any SCTranscriptViewerPlayer,
    alignment: SCTranscriptAlignment,
    hideAudioTags: Bool = true,
    contentSpacing: CGFloat = 16,
    contentInsets: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
    segmentComposer: ((SCTranscriptAlignment) -> SCTranscriptComposition)? = nil,
    onPlay: (() -> Void)? = nil,
    onPause: (() -> Void)? = nil,
    onTimeUpdate: ((TimeInterval) -> Void)? = nil,
    onEnded: (() -> Void)? = nil,
    onDurationChange: ((TimeInterval) -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.player = player
    self.alignment = alignment
    self.hideAudioTags = hideAudioTags
    self.contentSpacing = contentSpacing
    self.contentInsets = contentInsets
    self.segmentComposer = segmentComposer
    self.onPlay = onPlay
    self.onPause = onPause
    self.onTimeUpdate = onTimeUpdate
    self.onEnded = onEnded
    self.onDurationChange = onDurationChange
    self.content = content()
    self.composition =
      segmentComposer?(alignment)
      ?? SCTranscriptComposition.compose(alignment, hideAudioTags: hideAudioTags)
  }

  /// Creates a viewer from already-normalized word/gap timing. This is the
  /// native equivalent of upstream's custom `segmentComposer` path for ASR
  /// providers that return word timing without character alignment.
  public init(
    player: any SCTranscriptViewerPlayer,
    composition: SCTranscriptComposition,
    contentSpacing: CGFloat = 16,
    contentInsets: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
    onPlay: (() -> Void)? = nil,
    onPause: (() -> Void)? = nil,
    onTimeUpdate: ((TimeInterval) -> Void)? = nil,
    onEnded: (() -> Void)? = nil,
    onDurationChange: ((TimeInterval) -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.player = player
    self.alignment = nil
    self.hideAudioTags = false
    self.contentSpacing = contentSpacing
    self.contentInsets = contentInsets
    self.segmentComposer = nil
    self.onPlay = onPlay
    self.onPause = onPause
    self.onTimeUpdate = onTimeUpdate
    self.onEnded = onEnded
    self.onDurationChange = onDurationChange
    self.content = content()
    self.composition = composition
  }

  public var body: some View {
    SCTranscriptViewerProvider(context: context) {
      VStack(alignment: .leading, spacing: contentSpacing) {
        content
      }
      .padding(contentInsets)
    }
    .onChange(of: player.isPlaying) { _, playing in
      playbackStateChanged(isPlaying: playing)
    }
    .onChange(of: player.currentTime) { _, time in
      onTimeUpdate?(time)
    }
    .onChange(of: player.duration) { _, newDuration in
      if newDuration > 0 {
        onDurationChange?(newDuration)
      }
    }
  }

  /// The player's duration once metadata is known, otherwise the
  /// best-effort guess from the alignment — upstream's `guessedDuration`.
  private var duration: TimeInterval {
    if player.duration > 0 { return player.duration }
    if let last = alignment?.characterEndTimesSeconds.last, last.isFinite { return last }
    if let lastWord = composition.words.last, lastWord.endTime.isFinite { return lastWord.endTime }
    return 0
  }

  private var context: SCTranscriptViewerContext {
    let words = composition.words
    let segments = composition.segments
    let wordIndex = Self.currentWordIndex(at: player.currentTime, in: words)
    let currentWord = wordIndex >= 0 && wordIndex < words.count ? words[wordIndex] : nil
    let segmentIndex = currentWord?.segmentIndex ?? -1
    let player = player
    return SCTranscriptViewerContext(
      alignment: alignment,
      segments: segments,
      words: words,
      spokenSegments: segmentIndex <= 0 ? [] : Array(segments[0..<segmentIndex]),
      unspokenSegments: unspoken(after: segmentIndex, in: segments),
      currentWord: currentWord,
      currentSegmentIndex: segmentIndex,
      currentWordIndex: wordIndex,
      isPlaying: player.isPlaying,
      isScrubbing: isScrubbing,
      duration: duration,
      currentTime: player.currentTime,
      play: { player.play() },
      pause: { player.pause() },
      seekToTime: { player.seek(to: $0) },
      seekToWord: { player.seek(to: $0.startTime) },
      seekToWordAtIndex: { index in
        guard words.indices.contains(index) else { return }
        player.seek(to: words[index].startTime)
      },
      startScrubbing: { isScrubbing = true },
      endScrubbing: { isScrubbing = false }
    )
  }

  private func unspoken(after index: Int, in all: [SCTranscriptSegment]) -> [SCTranscriptSegment] {
    if all.isEmpty { return [] }
    if index == -1 { return all }
    if index + 1 >= all.count { return [] }
    return Array(all[(index + 1)...])
  }

  /// Upstream's `onPause`/`onEnded` events, derived: a pause observed at
  /// the end of the duration is `ended`.
  private func playbackStateChanged(isPlaying: Bool) {
    if isPlaying {
      onPlay?()
    } else if duration > 0 && player.currentTime >= duration - 0.05 {
      onEnded?()
    } else {
      onPause?()
    }
  }

  // MARK: Word tracking

  /// The word under the playhead — upstream's `findWordIndex` binary
  /// search plus its two fallbacks: the initial index-0 highlight
  /// before the first word starts, and the timing-gap snap to the
  /// latest word that started at or before the time.
  static func currentWordIndex(at time: TimeInterval, in words: [SCTranscriptWord]) -> Int {
    guard !words.isEmpty else { return -1 }
    if let found = containingWordIndex(at: time, in: words) { return found }
    guard let first = words.first, time >= first.startTime else { return 0 }
    var low = 0
    var high = words.count - 1
    var answer = 0
    while low <= high {
      let mid = (low + high) / 2
      if words[mid].startTime <= time {
        answer = mid
        low = mid + 1
      } else {
        high = mid - 1
      }
    }
    return answer
  }

  private static func containingWordIndex(at time: TimeInterval, in words: [SCTranscriptWord]) -> Int? {
    var low = 0
    var high = words.count - 1
    while low <= high {
      let mid = (low + high) / 2
      let word = words[mid]
      if time >= word.startTime && time < word.endTime { return mid }
      if time < word.startTime {
        high = mid - 1
      } else {
        low = mid + 1
      }
    }
    return nil
  }
}
