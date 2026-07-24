import SwiftUI

struct HistoryRecordControls<ContextAction: View>: View {
  let record: TranscriptRecord
  let transcriptMode: HistoryTranscriptViewMode
  let player: HistoryAudioPlayer
  let onSetTranscriptMode: (HistoryTranscriptViewMode) -> Void
  let onCopy: () -> Void
  let onShowDetails: () -> Void
  let onDelete: () -> Void
  private let contextAction: ContextAction

  init(
    record: TranscriptRecord,
    transcriptMode: HistoryTranscriptViewMode,
    player: HistoryAudioPlayer,
    onSetTranscriptMode: @escaping (HistoryTranscriptViewMode) -> Void,
    onCopy: @escaping () -> Void,
    onShowDetails: @escaping () -> Void,
    onDelete: @escaping () -> Void,
    @ViewBuilder contextAction: () -> ContextAction
  ) {
    self.record = record
    self.transcriptMode = transcriptMode
    self.player = player
    self.onSetTranscriptMode = onSetTranscriptMode
    self.onCopy = onCopy
    self.onShowDetails = onShowDetails
    self.onDelete = onDelete
    self.contextAction = contextAction()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
      HistoryPlaybackControls(record: record, player: player)

      HStack(spacing: AppSpacing.sm) {
        if record.availableTranscriptModes.count > 1 {
          HistoryTranscriptModePicker(
            selection: transcriptMode,
            availableModes: record.availableTranscriptModes,
            onSelect: onSetTranscriptMode
          )
          .disabled(!record.hasTranscriptText)
        }

        Spacer(minLength: AppSpacing.sm)

        contextAction
        HistoryIconAction(
          "Copy transcript",
          systemImage: "doc.on.doc",
          confirmationSystemImage: "checkmark",
          action: onCopy
        )
        .disabled(!record.hasTranscriptText)
        HistoryIconAction(
          "Recording information",
          systemImage: "info.circle",
          action: onShowDetails
        )
        HistoryIconAction(
          "Delete recording",
          systemImage: "trash",
          role: .destructive,
          action: onDelete
        )
      }

      HistoryRecordFooter(record: record)
    }
    .padding(.top, AppSpacing.sm)
  }
}

struct HistoryRecordFooter: View {
  let record: TranscriptRecord
  @Environment(\.theme) private var theme

  var body: some View {
    HStack(spacing: AppSpacing.md) {
      HStack(spacing: AppSpacing.sm) {
        Text(sourceAndWordCount)
          .lineLimit(1)
        if record.hasProcessedTranscript {
          SCBadge("AI processed", variant: .secondary)
        } else if record.status == .noSpeech {
          SCBadge("No voice detected", variant: .secondary)
        } else if record.status == .failed {
          SCBadge("Failed", variant: .secondary)
        }
      }
      Spacer(minLength: AppSpacing.sm)
      HStack(spacing: AppSpacing.xs) {
        Text(record.createdAt.formatted(date: .omitted, time: .shortened))
        Text("·")
        Text(HomePane.formatDuration(record.durationSeconds))
          .monospacedDigit()
      }
    }
    .font(.system(size: 10, weight: .medium))
    .foregroundStyle(theme.mutedForeground)
    .frame(maxWidth: .infinity)
    .padding(.vertical, AppSpacing.sm)
    .overlay(alignment: .top) {
      SCSeparator().opacity(0.6)
    }
  }

  private var sourceAndWordCount: String {
    let source = record.sourceApplicationName ?? "TimberVox"
    guard record.wordCount > 0 else { return source }
    return "\(source) · \(record.wordCount) words"
  }
}
