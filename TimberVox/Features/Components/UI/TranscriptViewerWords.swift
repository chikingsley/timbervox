// ============================================================
// TranscriptViewerWords.swift — swiftcn-ui (Audio)
// Word status, word rendering, and inline flow layout for the
// transcript-viewer registry item.
// ============================================================
import SwiftUI

// MARK: - Word status

/// How a word relates to the playhead — upstream's
/// `TranscriptViewerWordStatus`.
nonisolated public enum SCTranscriptViewerWordStatus: String, CaseIterable, Hashable, Sendable {
  case spoken
  case unspoken
  case current
}

// MARK: - Word

/// One transcript word with status styling — upstream's
/// `TranscriptViewerWord`: spoken words in the foreground color,
/// unspoken words muted, and the current word highlighted on the
/// primary color.
///
///     SCTranscriptViewerWord(word: word, status: .current)
public struct SCTranscriptViewerWord: View {
  @Environment(\.theme) private var theme

  var word: SCTranscriptWord
  var status: SCTranscriptViewerWordStatus

  /// - Parameters:
  ///   - word: The word to display.
  ///   - status: Its relation to the playhead.
  public init(word: SCTranscriptWord, status: SCTranscriptViewerWordStatus) {
    self.word = word
    self.status = status
  }

  public var body: some View {
    Text(word.text)
      .foregroundStyle(foreground)
      .padding(.horizontal, 2)
      .background {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(theme.primary.opacity(status == .current ? 1 : 0))
      }
      .animation(.easeOut(duration: 0.15), value: status)
  }

  private var foreground: Color {
    switch status {
    case .spoken: theme.foreground
    case .unspoken: theme.mutedForeground
    case .current: theme.primaryForeground
    }
  }
}

// MARK: - Words

/// The flowing transcript body — upstream's `TranscriptViewerWords`.
/// Renders every segment with its spoken/current/unspoken status, all
/// spoken once the playhead reaches the end. Custom word and gap
/// renderers replace the default views.
///
///     SCTranscriptViewerWords()
///
///     SCTranscriptViewerWords { word, status in
///         Text(word.text).underline(status == .current)
///     }
public struct SCTranscriptViewerWords<WordContent: View, GapContent: View>: View {
  @Environment(\.scTranscriptViewer) private var transcriptViewer

  var timeRange: Range<TimeInterval>?
  var renderWord: (SCTranscriptWord, SCTranscriptViewerWordStatus) -> WordContent
  var renderGap: (SCTranscriptGap, SCTranscriptViewerWordStatus) -> GapContent

  /// - Parameters:
  ///   - renderWord: Custom view for each word (upstream's `renderWord`
  ///     and the Word `children` slot).
  ///   - renderGap: Custom view for each whitespace gap (upstream's
  ///     `renderGap`).
  public init(
    timeRange: Range<TimeInterval>? = nil,
    @ViewBuilder renderWord: @escaping (SCTranscriptWord, SCTranscriptViewerWordStatus) -> WordContent,
    @ViewBuilder renderGap: @escaping (SCTranscriptGap, SCTranscriptViewerWordStatus) -> GapContent
  ) {
    self.timeRange = timeRange
    self.renderWord = renderWord
    self.renderGap = renderGap
  }

  public var body: some View {
    if let context = transcriptViewer {
      words(context)
    }
  }

  private func words(_ context: SCTranscriptViewerContext) -> some View {
    SCTranscriptFlowLayout(lineSpacing: 6) {
      ForEach(entries(context), id: \.segment.segmentIndex) { entry in
        switch entry.segment {
        case .word(let word):
          renderWord(word, entry.status)
            .contentShape(Rectangle())
            .onTapGesture {
              context.seekToWord(word)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(word.text)
            .accessibilityHint("Seek playback to this word")
            .accessibilityAction {
              context.seekToWord(word)
            }
        case .gap(let gap):
          renderGap(gap, entry.status)
            .transcriptGap()
        }
      }
    }
    .font(.title3)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityChildren {
      ForEach(visibleWords(context), id: \.segmentIndex) { word in
        Button(word.text) {
          context.seekToWord(word)
        }
        .accessibilityHint("Seek playback to this word")
      }
    }
  }

  private func visibleWords(_ context: SCTranscriptViewerContext) -> [SCTranscriptWord] {
    entries(context).compactMap { entry in
      guard case .word(let word) = entry.segment else { return nil }
      return word
    }
  }

  private struct Entry {
    var segment: SCTranscriptSegment
    var status: SCTranscriptViewerWordStatus
  }

  /// Upstream's `segmentsWithStatus`: everything spoken near the end,
  /// otherwise spoken + current + unspoken in original order.
  private func entries(_ context: SCTranscriptViewerContext) -> [Entry] {
    let nearEnd = context.duration > 0 && context.currentTime >= context.duration - 0.01
    if let timeRange {
      let includedWords = context.words.filter {
        $0.endTime > timeRange.lowerBound && $0.startTime < timeRange.upperBound
      }
      guard let first = includedWords.first, let last = includedWords.last else { return [] }
      return context.segments
        .filter { first.segmentIndex...last.segmentIndex ~= $0.segmentIndex }
        .map { segment in
          Entry(
            segment: segment,
            status: status(
              for: segment,
              currentSegmentIndex: context.currentSegmentIndex,
              nearEnd: nearEnd
            )
          )
        }
    }
    if nearEnd {
      return context.segments.map { Entry(segment: $0, status: .spoken) }
    }
    var entries = context.spokenSegments.map { Entry(segment: $0, status: .spoken) }
    if let currentWord = context.currentWord {
      entries.append(Entry(segment: .word(currentWord), status: .current))
    }
    entries.append(contentsOf: context.unspokenSegments.map { Entry(segment: $0, status: .unspoken) })
    return entries
  }

  private func status(
    for segment: SCTranscriptSegment,
    currentSegmentIndex: Int,
    nearEnd: Bool
  ) -> SCTranscriptViewerWordStatus {
    if nearEnd || segment.segmentIndex < currentSegmentIndex { return .spoken }
    if segment.segmentIndex == currentSegmentIndex { return .current }
    return .unspoken
  }
}

extension SCTranscriptViewerWords where WordContent == SCTranscriptViewerWord, GapContent == Text {
  /// Default rendering: `SCTranscriptViewerWord` per word, a plain
  /// space per gap.
  public init() {
    self.init(
      renderWord: { word, status in SCTranscriptViewerWord(word: word, status: status) },
      renderGap: { _, _ in Text(" ") }
    )
  }

  /// Default rendering restricted to words overlapping `timeRange`.
  public init(timeRange: Range<TimeInterval>) {
    self.init(
      timeRange: timeRange,
      renderWord: { word, status in SCTranscriptViewerWord(word: word, status: status) },
      renderGap: { _, _ in Text(" ") }
    )
  }
}

extension SCTranscriptViewerWords where GapContent == Text {
  /// Custom words with default gaps.
  public init(@ViewBuilder renderWord: @escaping (SCTranscriptWord, SCTranscriptViewerWordStatus) -> WordContent) {
    self.init(renderWord: renderWord) { _, _ in Text(" ") }
  }

  /// Custom word rendering restricted to words overlapping `timeRange`.
  public init(
    timeRange: Range<TimeInterval>,
    @ViewBuilder renderWord: @escaping (SCTranscriptWord, SCTranscriptViewerWordStatus) -> WordContent
  ) {
    self.init(timeRange: timeRange, renderWord: renderWord) { _, _ in Text(" ") }
  }
}

extension SCTranscriptViewerWords where WordContent == SCTranscriptViewerWord {
  /// Default words with custom gaps.
  public init(@ViewBuilder renderGap: @escaping (SCTranscriptGap, SCTranscriptViewerWordStatus) -> GapContent) {
    self.init(
      renderWord: { word, status in SCTranscriptViewerWord(word: word, status: status) },
      renderGap: renderGap
    )
  }
}

// MARK: Flow layout

/// Marks a subview as a whitespace gap so the flow layout lets it hang
/// at line ends the way HTML collapses trailing whitespace.
private struct SCTranscriptGapLayoutKey: LayoutValueKey {
  static let defaultValue = false
}

extension View {
  fileprivate func transcriptGap() -> some View {
    layoutValue(key: SCTranscriptGapLayoutKey.self, value: true)
  }
}

/// Inline word wrapping for the transcript — the flow behavior of
/// upstream's inline spans. Words wrap to new lines; gaps never force a
/// wrap and hang past the trailing edge instead.
private struct SCTranscriptFlowLayout: Layout {
  private struct Arrangement {
    let positions: [CGPoint]
    let sizes: [CGSize]
    let size: CGSize
  }

  var lineSpacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    arrange(width: proposal.width ?? .infinity, subviews: subviews).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let arrangement = arrange(width: bounds.width, subviews: subviews)
    for (index, subview) in subviews.enumerated() {
      let position = arrangement.positions[index]
      subview.place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        anchor: .topLeading,
        proposal: ProposedViewSize(arrangement.sizes[index])
      )
    }
  }

  private func arrange(
    width: CGFloat,
    subviews: Subviews
  ) -> Arrangement {
    var positions: [CGPoint] = []
    positions.reserveCapacity(subviews.count)
    var sizes: [CGSize] = []
    sizes.reserveCapacity(subviews.count)
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    var maxX: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      let isGap = subview[SCTranscriptGapLayoutKey.self]
      if !isGap && x > 0 && x + size.width > width {
        x = 0
        y += lineHeight + lineSpacing
        lineHeight = 0
      }
      positions.append(CGPoint(x: x, y: y))
      sizes.append(size)
      x += size.width
      lineHeight = max(lineHeight, size.height)
      maxX = max(maxX, min(x, width.isFinite ? width : x))
    }
    let height = subviews.isEmpty ? 0 : y + lineHeight
    return Arrangement(
      positions: positions,
      sizes: sizes,
      size: CGSize(width: width.isFinite ? width : maxX, height: height)
    )
  }
}
