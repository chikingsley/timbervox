// Transcript-viewer timing models, player seam, context, and provider.
// HTMLAudioElement becomes SCTranscriptViewerPlayer; SwiftUI environment
// values replace the upstream React provider and context hook.
import SwiftUI

// MARK: - Alignment

/// Character-level timing data for one narration — upstream's
/// `CharacterAlignmentResponseModel` (the ElevenLabs alignment payload).
nonisolated public struct SCTranscriptAlignment: Hashable, Sendable, Codable {
  /// Every character of the transcript, in order.
  public var characters: [String]
  /// Start time of each character, in seconds.
  public var characterStartTimesSeconds: [Double]
  /// End time of each character, in seconds.
  public var characterEndTimesSeconds: [Double]

  /// Creates alignment data from parallel character/timing arrays.
  public init(
    characters: [String],
    characterStartTimesSeconds: [Double],
    characterEndTimesSeconds: [Double]
  ) {
    self.characters = characters
    self.characterStartTimesSeconds = characterStartTimesSeconds
    self.characterEndTimesSeconds = characterEndTimesSeconds
  }
}

// MARK: - Segments

/// One timed word — upstream's `TranscriptWord`.
nonisolated public struct SCTranscriptWord: Hashable, Sendable {
  /// Position within the full segment list.
  public var segmentIndex: Int
  /// Position within the word list.
  public var wordIndex: Int
  /// The word text.
  public var text: String
  /// When the word starts, in seconds.
  public var startTime: Double
  /// When the word ends, in seconds.
  public var endTime: Double

  /// Creates a timed word.
  public init(segmentIndex: Int, wordIndex: Int, text: String, startTime: Double, endTime: Double) {
    self.segmentIndex = segmentIndex
    self.wordIndex = wordIndex
    self.text = text
    self.startTime = startTime
    self.endTime = endTime
  }
}

/// Whitespace between words — upstream's `GapSegment`.
nonisolated public struct SCTranscriptGap: Hashable, Sendable {
  /// Position within the full segment list.
  public var segmentIndex: Int
  /// The raw whitespace text.
  public var text: String

  /// Creates a gap segment.
  public init(segmentIndex: Int, text: String) {
    self.segmentIndex = segmentIndex
    self.text = text
  }
}

/// A word or a gap — upstream's `TranscriptSegment` union.
nonisolated public enum SCTranscriptSegment: Hashable, Sendable {
  case word(SCTranscriptWord)
  case gap(SCTranscriptGap)

  /// Position within the full segment list.
  public var segmentIndex: Int {
    switch self {
    case .word(let word): word.segmentIndex
    case .gap(let gap): gap.segmentIndex
    }
  }

  /// The segment text.
  public var text: String {
    switch self {
    case .word(let word): word.text
    case .gap(let gap): gap.text
    }
  }
}

/// The segments and words composed from alignment data — upstream's
/// `ComposeSegmentsResult`.
nonisolated public struct SCTranscriptComposition: Hashable, Sendable {
  /// Every segment (words and gaps), in order.
  public var segments: [SCTranscriptSegment]
  /// Just the timed words, in order.
  public var words: [SCTranscriptWord]

  /// Creates a composition from already-built segments.
  public init(segments: [SCTranscriptSegment], words: [SCTranscriptWord]) {
    self.segments = segments
    self.words = words
  }

  /// Splits character alignment into timed words and whitespace gaps —
  /// upstream's `composeSegments`. With `hideAudioTags`, bracketed
  /// audio tags such as `[laughs]` are removed along with the
  /// whitespace before them.
  public static func compose(_ alignment: SCTranscriptAlignment, hideAudioTags: Bool = false) -> Self {
    var builder = SCTranscriptSegmentBuilder(hideAudioTags: hideAudioTags)
    for (index, character) in alignment.characters.enumerated() {
      let start =
        index < alignment.characterStartTimesSeconds.count
        ? alignment.characterStartTimesSeconds[index] : 0
      let end =
        index < alignment.characterEndTimesSeconds.count
        ? alignment.characterEndTimesSeconds[index] : start
      builder.consume(character, start: start, end: end)
    }
    return builder.finish()
  }
}

/// The character-by-character state machine inside `compose` —
/// upstream's word/whitespace/audio-tag buffers.
private struct SCTranscriptSegmentBuilder {
  let hideAudioTags: Bool
  private var segments: [SCTranscriptSegment] = []
  private var words: [SCTranscriptWord] = []
  private var wordBuffer = ""
  private var whitespaceBuffer = ""
  private var wordStart = 0.0
  private var wordEnd = 0.0
  private var segmentIndex = 0
  private var wordIndex = 0
  private var insideAudioTag = false

  init(hideAudioTags: Bool) {
    self.hideAudioTags = hideAudioTags
  }

  mutating func consume(_ character: String, start: Double, end: Double) {
    if hideAudioTags {
      if character == "[" {
        flushWord()
        whitespaceBuffer = ""
        insideAudioTag = true
        return
      }
      if insideAudioTag {
        if character == "]" {
          insideAudioTag = false
        }
        return
      }
    }
    if character.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
      flushWord()
      whitespaceBuffer += character
      return
    }
    if !whitespaceBuffer.isEmpty {
      flushWhitespace()
    }
    if wordBuffer.isEmpty {
      wordBuffer = character
      wordStart = start
      wordEnd = end
    } else {
      wordBuffer += character
      wordEnd = end
    }
  }

  mutating func finish() -> SCTranscriptComposition {
    flushWord()
    flushWhitespace()
    return SCTranscriptComposition(segments: segments, words: words)
  }

  private mutating func flushWhitespace() {
    guard !whitespaceBuffer.isEmpty else { return }
    segments.append(.gap(SCTranscriptGap(segmentIndex: segmentIndex, text: whitespaceBuffer)))
    segmentIndex += 1
    whitespaceBuffer = ""
  }

  private mutating func flushWord() {
    guard !wordBuffer.isEmpty else { return }
    let word = SCTranscriptWord(
      segmentIndex: segmentIndex,
      wordIndex: wordIndex,
      text: wordBuffer,
      startTime: wordStart,
      endTime: wordEnd
    )
    segments.append(.word(word))
    words.append(word)
    segmentIndex += 1
    wordIndex += 1
    wordBuffer = ""
  }
}

// MARK: - Player

/// The playback seam behind `SCTranscriptViewerContainer` — the surface
/// of the HTMLAudioElement that upstream's `useTranscriptViewer` hook
/// consumes, as an observable protocol. Conform with AVPlayer,
/// AVAudioPlayer, or any clock; the engine owns the audio source
/// (upstream's `audioSrc`/`audioType`), loading, and volume.
///
///     @Observable final class NarrationPlayer: SCTranscriptViewerPlayer {
///         private(set) var isPlaying = false
///         private(set) var currentTime: TimeInterval = 0
///         private(set) var duration: TimeInterval = 0
///         func play() { /* start the engine */ }
///         func pause() { /* pause the engine */ }
///         func seek(to time: TimeInterval) { currentTime = time /* + engine seek */ }
///     }
@MainActor
public protocol SCTranscriptViewerPlayer: AnyObject, Observable {
  /// Whether audio is playing — `!audio.paused`.
  var isPlaying: Bool { get }
  /// The playback position in seconds — `audio.currentTime`.
  var currentTime: TimeInterval { get }
  /// The total duration in seconds, `0` until known — `audio.duration`.
  var duration: TimeInterval { get }
  /// Starts playback — `audio.play()`.
  func play()
  /// Pauses playback — `audio.pause()`.
  func pause()
  /// Moves the playhead. Update `currentTime` synchronously so rapid
  /// scrubs render immediately (upstream's optimistic seek).
  func seek(to time: TimeInterval)
}

// MARK: - Context

/// What `SCTranscriptViewerContainer` publishes to its parts through the
/// environment — upstream's `useTranscriptViewerContext` value. Read it
/// from custom parts via `@Environment(\.scTranscriptViewer)`.
public struct SCTranscriptViewerContext {
  /// The original character alignment payload, when the provider exposes
  /// character timing rather than an already-composed word timeline.
  public var alignment: SCTranscriptAlignment?
  /// Every segment (words and gaps), in order.
  public var segments: [SCTranscriptSegment]
  /// Just the timed words, in order.
  public var words: [SCTranscriptWord]
  /// Segments before the current word.
  public var spokenSegments: [SCTranscriptSegment]
  /// Segments after the current word.
  public var unspokenSegments: [SCTranscriptSegment]
  /// The word at the playhead, if any.
  public var currentWord: SCTranscriptWord?
  /// Segment index of the current word, `-1` when none.
  public var currentSegmentIndex: Int
  /// Word index of the current word, `-1` when none.
  public var currentWordIndex: Int
  /// Whether audio is playing.
  public var isPlaying: Bool
  /// Whether a scrub interaction is in progress.
  public var isScrubbing: Bool
  /// The effective duration: the player's when known, otherwise the
  /// alignment's final end time.
  public var duration: TimeInterval
  /// The playback position in seconds.
  public var currentTime: TimeInterval
  /// Starts playback.
  public var play: @MainActor () -> Void
  /// Pauses playback.
  public var pause: @MainActor () -> Void
  /// Moves the playhead to a time.
  public var seekToTime: @MainActor (TimeInterval) -> Void
  /// Moves the playhead to a word's start.
  public var seekToWord: @MainActor (SCTranscriptWord) -> Void
  /// Moves the playhead to the indexed word's start, when it exists.
  public var seekToWordAtIndex: @MainActor (Int) -> Void
  /// Marks the start of a scrub interaction.
  public var startScrubbing: @MainActor () -> Void
  /// Marks the end of a scrub interaction.
  public var endScrubbing: @MainActor () -> Void

  /// Creates the value published by `SCTranscriptViewerProvider`.
  public init(
    alignment: SCTranscriptAlignment?,
    segments: [SCTranscriptSegment],
    words: [SCTranscriptWord],
    spokenSegments: [SCTranscriptSegment],
    unspokenSegments: [SCTranscriptSegment],
    currentWord: SCTranscriptWord?,
    currentSegmentIndex: Int,
    currentWordIndex: Int,
    isPlaying: Bool,
    isScrubbing: Bool,
    duration: TimeInterval,
    currentTime: TimeInterval,
    play: @escaping @MainActor () -> Void,
    pause: @escaping @MainActor () -> Void,
    seekToTime: @escaping @MainActor (TimeInterval) -> Void,
    seekToWord: @escaping @MainActor (SCTranscriptWord) -> Void,
    seekToWordAtIndex: @escaping @MainActor (Int) -> Void,
    startScrubbing: @escaping @MainActor () -> Void,
    endScrubbing: @escaping @MainActor () -> Void
  ) {
    self.alignment = alignment
    self.segments = segments
    self.words = words
    self.spokenSegments = spokenSegments
    self.unspokenSegments = unspokenSegments
    self.currentWord = currentWord
    self.currentSegmentIndex = currentSegmentIndex
    self.currentWordIndex = currentWordIndex
    self.isPlaying = isPlaying
    self.isScrubbing = isScrubbing
    self.duration = duration
    self.currentTime = currentTime
    self.play = play
    self.pause = pause
    self.seekToTime = seekToTime
    self.seekToWord = seekToWord
    self.seekToWordAtIndex = seekToWordAtIndex
    self.startScrubbing = startScrubbing
    self.endScrubbing = endScrubbing
  }
}

private struct SCTranscriptViewerContextKey: EnvironmentKey {
  static var defaultValue: SCTranscriptViewerContext? { nil }
}

extension EnvironmentValues {
  /// The nearest enclosing transcript-viewer provider context —
  /// upstream's `useTranscriptViewerContext`. `nil` outside a container.
  public var scTranscriptViewer: SCTranscriptViewerContext? {
    get { self[SCTranscriptViewerContextKey.self] }
    set { self[SCTranscriptViewerContextKey.self] = newValue }
  }
}

// MARK: - Provider

/// Publishes a transcript-viewer context to compound parts — upstream's
/// `TranscriptViewerProvider`. `SCTranscriptViewerContainer` composes this
/// automatically; expose it directly when a custom root owns the state.
public struct SCTranscriptViewerProvider<Content: View>: View {
  var context: SCTranscriptViewerContext
  var content: Content

  /// - Parameters:
  ///   - context: The complete transcript-viewer state and commands.
  ///   - content: Compound transcript-viewer parts or custom parts.
  public init(
    context: SCTranscriptViewerContext,
    @ViewBuilder content: () -> Content
  ) {
    self.context = context
    self.content = content()
  }

  public var body: some View {
    content.environment(\.scTranscriptViewer, context)
  }
}
