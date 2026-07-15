import AppKit
import SwiftUI

struct HistoryRecordCard: View {
  let record: TranscriptRecord
  let isExpanded: Bool
  let isDimmed: Bool
  let transcriptMode: HistoryTranscriptViewMode
  let onToggleExpanded: () -> Void
  let onOpenDetail: () -> Void
  let onSetTranscriptMode: (HistoryTranscriptViewMode) -> Void
  let onCopy: () -> Void
  let onShowDetails: () -> Void
  let onDelete: () -> Void
  @State private var player = HistoryAudioPlayer()
  @Environment(\.theme) private var theme

  var body: some View {
    SCCard(size: .sm) {
      SCCardContent {
        if isExpanded {
          SCTranscriptViewerContainer(
            player: player,
            composition: record.transcriptViewerComposition,
            contentSpacing: 0,
            contentInsets: EdgeInsets()
          ) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
              HistoryTranscriptContent(record: record, mode: transcriptMode)
                .frame(maxWidth: .infinity, alignment: .leading)

              Button(action: onToggleExpanded) {
                Image(systemName: "chevron.up")
              }
              .buttonStyle(.sc(.ghost, size: .iconXS))
              .help("Collapse dictation")
              .accessibilityLabel("Collapse dictation")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            HistoryRecordControls(
              record: record,
              transcriptMode: transcriptMode,
              player: player,
              onSetTranscriptMode: onSetTranscriptMode,
              onCopy: onCopy,
              onShowDetails: onShowDetails,
              onDelete: onDelete
            ) {
              HistoryIconAction(
                "Open full transcript",
                systemImage: "arrow.up.left.and.arrow.down.right",
                action: onOpenDetail
              )
            }
          }
          .task(id: record.audioPath) {
            await player.load(audioPath: record.audioPath)
          }
          .onDisappear {
            player.stop()
          }
        } else {
          HistoryTranscriptToggle(action: onToggleExpanded) {
            collapsedContent
          }
          .accessibilityLabel(collapsedActionLabel)
          .accessibilityValue(record.text)
        }

        if !isExpanded {
          HistoryRecordFooter(record: record)
        }
      }
    }
    .opacity(isDimmed ? 0.48 : 1)
    .animation(.easeOut(duration: 0.15), value: isExpanded)
    .animation(.easeOut(duration: 0.15), value: isDimmed)
    .contextMenu {
      Button("Copy", action: onCopy)
        .disabled(!record.hasTranscriptText)
      Button("Recording information", action: onShowDetails)
      Divider()
      Button("Delete", role: .destructive, action: onDelete)
    }
  }

  private var collapsedContent: some View {
    HStack(alignment: .center, spacing: 12) {
      HistorySourceApplicationIcon(record: record, size: 32)

      Text(record.historyHeadline)
        .font(.system(size: 13, weight: .medium))
        .lineSpacing(1)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)

      Image(systemName: collapsedActionSystemImage)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(theme.mutedForeground)
    }
  }

  private var collapsedActionLabel: String {
    HistoryPresentationPolicy.shouldOpenInDetail(record)
      ? "Open dictation"
      : "Expand dictation"
  }

  private var collapsedActionSystemImage: String {
    HistoryPresentationPolicy.shouldOpenInDetail(record)
      ? "chevron.right"
      : "chevron.down"
  }
}

struct HistoryTranscriptContent: View {
  let record: TranscriptRecord
  let mode: HistoryTranscriptViewMode
  var searchQuery = ""
  @Environment(\.theme) private var theme

  var body: some View {
    if record.status != .succeeded {
      VStack(alignment: .leading, spacing: AppSpacing.md) {
        SCAlert(
          icon: record.status == .noSpeech ? "waveform.slash" : "exclamationmark.triangle",
          title: record.status == .noSpeech ? "No voice detected" : "Dictation failed",
          description: record.errorMessage ?? record.historyHeadline,
          variant: .destructive
        )
        if record.hasTranscriptText {
          if mode == .segmented, record.hasTimedTranscript {
            segmentedTranscript
          } else {
            highlightedText(record.rawTranscriptText)
              .font(.system(size: 13, weight: .medium))
              .lineSpacing(2)
              .textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else if mode == .segmented, record.hasTimedTranscript {
      segmentedTranscript
    } else {
      highlightedText(record.transcriptText(for: mode))
        .font(.system(size: 13, weight: .medium))
        .lineSpacing(2)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder private var segmentedTranscript: some View {
    if record.timedSegments.isEmpty {
      SCTranscriptViewerWords { word, status in
        SCTranscriptViewerWord(word: word, status: status)
          .font(.system(size: 13, weight: .medium))
          .background(searchHighlight(for: word.text))
      }
    } else {
      LazyVStack(alignment: .leading, spacing: 24) {
        ForEach(Array(record.timedSegments.enumerated()), id: \.offset) { _, segment in
          HStack(alignment: .top, spacing: 18) {
            Text(Self.timestamp(segment.startSeconds))
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(theme.mutedForeground)
              .monospacedDigit()
              .frame(width: 42, alignment: .leading)
            SCTranscriptViewerWords(
              timeRange: segment.startSeconds..<segment.endSeconds
            ) { word, status in
              SCTranscriptViewerWord(word: word, status: status)
                .font(.system(size: 13, weight: .medium))
                .background(searchHighlight(for: word.text))
            }
          }
        }
      }
    }
  }

  private func searchHighlight(for word: String) -> Color {
    guard !trimmedSearchQuery.isEmpty else { return .clear }
    return word.localizedCaseInsensitiveContains(trimmedSearchQuery)
      ? Color(nsColor: .systemYellow).opacity(0.65)
      : .clear
  }

  private static func timestamp(_ seconds: Double) -> String {
    Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
  }

  private func highlightedText(_ text: String) -> Text {
    let query = trimmedSearchQuery
    guard !query.isEmpty else { return Text(text) }

    var attributed = AttributedString(text)
    var searchRange = text.startIndex..<text.endIndex
    while let match = text.range(
      of: query,
      options: [.caseInsensitive, .diacriticInsensitive],
      range: searchRange
    ),
      let lower = AttributedString.Index(match.lowerBound, within: attributed),
      let upper = AttributedString.Index(match.upperBound, within: attributed)
    {
      attributed[lower..<upper].backgroundColor = Color(nsColor: .systemYellow)
      attributed[lower..<upper].foregroundColor = Color(nsColor: .black)
      attributed[lower..<upper].font = .system(size: 13, weight: .semibold)
      searchRange = match.upperBound..<text.endIndex
    }
    return Text(attributed)
  }

  private var trimmedSearchQuery: String {
    searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

private struct HistoryTranscriptToggle<Content: View>: View {
  let action: () -> Void
  let content: Content
  @State private var isHovered = false

  init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
    self.action = action
    self.content = content()
  }

  var body: some View {
    Button(action: action) {
      content
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
    .buttonStyle(HistoryTranscriptToggleStyle(isHovered: isHovered))
    .onHover { isHovered = $0 }
  }
}

private struct HistoryTranscriptToggleStyle: ButtonStyle {
  let isHovered: Bool
  @Environment(\.theme) private var theme

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(isHovered ? theme.accentForeground : theme.foreground)
      .background(
        configuration.isPressed || isHovered ? theme.accent : .clear,
        in: shape
      )
      .contentShape(shape)
      .animation(.easeOut(duration: 0.12), value: isHovered)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: max(theme.radius - 2, 4), style: .continuous)
  }
}

struct HistoryTranscriptModePicker: View {
  let selection: HistoryTranscriptViewMode
  let availableModes: [HistoryTranscriptViewMode]
  let onSelect: (HistoryTranscriptViewMode) -> Void

  var body: some View {
    SCToggleGroup(
      selection: Binding<HistoryTranscriptViewMode?>(
        get: { selection },
        set: { mode in
          if let mode { onSelect(mode) }
        }
      ),
      items: HistoryTranscriptViewMode.allCases.map { mode in
        SCToggleGroupItem(
          value: mode,
          label: mode.label,
          isDisabled: !availableModes.contains(mode)
        )
      }
    )
    .help(
      "Choose among the artifacts available for this dictation"
    )
  }
}

struct HistoryIconAction: View {
  let label: String
  let systemImage: String
  let confirmationSystemImage: String?
  let role: ButtonRole?
  let action: () -> Void
  @State private var isConfirmed = false

  init(
    _ label: String,
    systemImage: String,
    confirmationSystemImage: String? = nil,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
  ) {
    self.label = label
    self.systemImage = systemImage
    self.confirmationSystemImage = confirmationSystemImage
    self.role = role
    self.action = action
  }

  var body: some View {
    Button(role: role) {
      action()
      showConfirmation()
    } label: {
      Image(systemName: isConfirmed ? (confirmationSystemImage ?? systemImage) : systemImage)
    }
    .buttonStyle(.sc(role == .destructive ? .destructive : .ghost, size: .iconXS))
    .help(label)
    .accessibilityLabel(label)
  }

  private func showConfirmation() {
    guard confirmationSystemImage != nil else { return }
    isConfirmed = true
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(2))
      isConfirmed = false
    }
  }
}
