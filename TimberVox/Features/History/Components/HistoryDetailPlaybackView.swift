import SwiftUI

struct HistoryDetailPlaybackView<ContextAction: View>: View {
  let record: TranscriptRecord
  let transcriptMode: HistoryTranscriptViewMode
  let searchQuery: String
  let player: HistoryAudioPlayer
  let isRerunning: Bool
  let rerunError: String?
  let onSetTranscriptMode: (HistoryTranscriptViewMode) -> Void
  let onCopy: () -> Void
  let onShowDetails: () -> Void
  let onDelete: () -> Void
  private let contextAction: ContextAction
  @Environment(\.theme) private var theme

  init(
    record: TranscriptRecord,
    transcriptMode: HistoryTranscriptViewMode,
    searchQuery: String,
    player: HistoryAudioPlayer,
    isRerunning: Bool,
    rerunError: String?,
    onSetTranscriptMode: @escaping (HistoryTranscriptViewMode) -> Void,
    onCopy: @escaping () -> Void,
    onShowDetails: @escaping () -> Void,
    onDelete: @escaping () -> Void,
    @ViewBuilder contextAction: () -> ContextAction
  ) {
    self.record = record
    self.transcriptMode = transcriptMode
    self.searchQuery = searchQuery
    self.player = player
    self.isRerunning = isRerunning
    self.rerunError = rerunError
    self.onSetTranscriptMode = onSetTranscriptMode
    self.onCopy = onCopy
    self.onShowDetails = onShowDetails
    self.onDelete = onDelete
    self.contextAction = contextAction()
  }

  var body: some View {
    SCTranscriptViewerContainer(
      player: player,
      composition: record.transcriptViewerComposition,
      contentSpacing: 0,
      contentInsets: EdgeInsets()
    ) {
      VStack(spacing: 0) {
        ScrollView {
          HistoryTranscriptContent(
            record: record,
            mode: transcriptMode,
            searchQuery: searchQuery
          )
          .appContentColumn(topInset: AppSpacing.lg, bottomInset: AppSpacing.lg)
        }
        .scrollIndicators(.hidden)

        if isRerunning {
          HStack(spacing: 8) {
            SCSpinner(size: 14, lineWidth: 1.5)
            Text("Re-transcribing…")
          }
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(theme.mutedForeground)
          .padding(.horizontal, 24)
          .padding(.bottom, 8)
        }

        if let rerunError {
          Text(rerunError)
            .font(.system(size: 11))
            .foregroundStyle(theme.destructive)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }

        HistoryRecordControls(
          record: record,
          transcriptMode: transcriptMode,
          player: player,
          onSetTranscriptMode: onSetTranscriptMode,
          onCopy: onCopy,
          onShowDetails: onShowDetails,
          onDelete: onDelete
        ) {
          contextAction
        }
        .appContentColumn(bottomInset: AppSpacing.lg)
        .background(theme.background)
      }
    }
    .task(id: record.audioPath) {
      await player.load(audioPath: record.audioPath)
    }
    .onDisappear {
      player.stop()
    }
  }
}
