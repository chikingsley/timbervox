import GRDB
import SwiftUI

struct HomePane: View {
  let dictation: DictationController
  @Binding var activeTab: ActiveTab?
  @Binding var selectedHistoryID: Int64?
  @State private var overview = HomeDictationOverview.empty
  @State private var historyError: String?
  @State private var axTrusted = true
  @Environment(\.theme) private var theme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppSpacing.lg) {
        statistics
        quickActions

        if let notice = currentNotice {
          HomeNotice(notice: notice)
        }

        HomeRecentActivityCard(
          records: overview.recentRecords,
          errorMessage: historyError,
          onViewHistory: { openHistory() },
          onSelectRecord: { openHistory(selectedID: $0) }
        )
      }
      .appContentColumn(topInset: AppSpacing.lg, bottomInset: AppSpacing.xl)
    }
    .scrollIndicators(.hidden)
    .foregroundStyle(theme.foreground)
    .background(theme.background)
    .task {
      await observeOverview()
    }
    .task {
      axTrusted = AccessibilityPermission.isTrusted
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        axTrusted = AccessibilityPermission.isTrusted
      }
    }
  }

  private var statistics: some View {
    SCCard(size: .sm) {
      SCCardContent {
        HStack(spacing: 16) {
          HomeStatistic(value: "\(averageWordsPerMinute) WPM", label: "Average speed")
          HomeStatistic(value: "\(overview.totalWords)", label: "Words")
          HomeStatistic(value: "\(overview.dictationCount)", label: "Dictations")
          HomeStatistic(
            value: Self.formatCompactDuration(overview.totalDurationSeconds),
            label: "Saved all time",
            showsDivider: false
          )
        }
      }
    }
  }

  private var quickActions: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
      spacing: 8
    ) {
      HomeActionTile(
        title: dictation.isRecording ? "Stop recording" : "Start recording",
        icon: dictation.isRecording ? "stop.fill" : "mic",
        shortcut: "⌥ Space",
        action: dictation.toggle
      )

      HomeActionTile(title: "View history", icon: "clock") {
        openHistory()
      }

      HomeActionTile(title: "Choose a mode", icon: "slider.horizontal.3") {
        activeTab = .modes
      }

      HomeActionTile(title: "Transcription models", icon: "waveform") {
        activeTab = .modes
      }

      HomeActionTile(
        title: "Copy latest",
        icon: "doc.on.doc",
        isEnabled: dictation.lastTranscript != nil,
        action: dictation.copyLastTranscript
      )

      HomeActionTile(title: "Accessibility", icon: "accessibility") {
        AccessibilityPermission.requestPrompt()
      }

      HomeActionTile(title: "Keyboard shortcuts", icon: "keyboard") {
        activeTab = .settings
      }

      HomeActionTile(title: "Account & billing", icon: "person.crop.circle") {
        activeTab = .settings
      }
    }
  }

  private var currentNotice: HomeNotice.Content? {
    if !axTrusted {
      return .init(
        icon: "exclamationmark.triangle",
        title: "Auto-paste is off",
        message: "Grant Accessibility so your words return to the app you are dictating into."
      )
    }

    switch dictation.state {
    case .recording(let started):
      return .init(
        icon: "waveform",
        title: "Listening",
        message: "Recording started \(started.formatted(date: .omitted, time: .shortened)). Press ⌥Space to stop."
      )
    case .transcribing:
      return .init(
        icon: "ellipsis",
        title: "Transcribing",
        message: "TimberVox is preparing and delivering your text."
      )
    case .idle:
      return nil
    }
  }

  private func openHistory(selectedID: Int64? = nil) {
    NavigationPerformance.beginHomeToHistory()
    selectedHistoryID = selectedID
    activeTab = .history
  }

  private var averageWordsPerMinute: Int {
    guard overview.totalDurationSeconds > 0 else { return 0 }
    return Int((Double(overview.totalWords) / (overview.totalDurationSeconds / 60)).rounded())
  }

  static func formatDuration(_ seconds: TimeInterval) -> String {
    Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
  }

  private static func formatCompactDuration(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds / 60)
    if minutes < 60 { return "\(minutes) minutes" }
    let hours = minutes / 60
    let remainder = minutes % 60
    return remainder == 0 ? "\(hours) hours" : "\(hours)h \(remainder)m"
  }

  private func observeOverview() async {
    do {
      for try await value in try TranscriptStore.shared.observeHomeOverview() {
        overview = value
        historyError = nil
      }
    } catch {
      overview = .empty
      historyError = error.localizedDescription
    }
  }
}
