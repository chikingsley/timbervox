import SwiftUI
import TimberVoxCore

private struct HomeTile: Identifiable {
  let icon: String
  let title: String
  let action: HomeTileAction
  var id: HomeTileAction { action }
}

private enum HomeTileAction: Hashable {
  case toggleRecording
  case createMode
  case manageModels
  case addShortcut
}

private struct HomeStats {
  private static let secondsPerMinute = 60.0
  static let typingWPM = 40

  let wordCount: Int
  let averageWPM: Int
  let appCount: Int
  let savedSeconds: TimeInterval

  init(records: [TranscriptRecord]) {
    let computedWordCount = records.reduce(0) { total, record in
      total + Self.wordCount(in: record.finalText)
    }
    let totalDuration = records.reduce(0) { total, record in
      total + max(0, record.duration)
    }
    let computedAverageWPM: Int
    if totalDuration > 0, computedWordCount > 0 {
      computedAverageWPM = Int((Double(computedWordCount) / (totalDuration / Self.secondsPerMinute)).rounded())
    } else {
      computedAverageWPM = 0
    }
    let typingSeconds = Double(computedWordCount) / Double(Self.typingWPM) * Self.secondsPerMinute

    wordCount = computedWordCount
    averageWPM = computedAverageWPM
    appCount = Set(records.compactMap(\.sourceAppBundleID)).count
    savedSeconds = max(0, typingSeconds - totalDuration)
  }

  var averageSpeedValue: String {
    "\(averageWPM.formatted()) WPM"
  }

  var wordsValue: String {
    wordCount.formatted()
  }

  var appsUsedValue: String {
    appCount.formatted()
  }

  var timeSavedValue: String {
    Self.formatSavedTime(savedSeconds)
  }

  private static func wordCount(in text: String) -> Int {
    text.split { $0.isWhitespace || $0.isNewline }.count
  }

  private static func formatSavedTime(_ seconds: TimeInterval) -> String {
    let totalMinutes = max(0, Int((seconds / Self.secondsPerMinute).rounded()))
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0, minutes > 0 {
      return "\(hours) hr \(minutes) min"
    }
    if hours > 0 {
      return "\(hours) hr"
    }
    return "\(minutes) min"
  }
}

struct HomePane: View {
  @Bindable var historyStore: HistoryStore
  @Bindable var settingsStore: SettingsStore
  var transcriptionStore: TranscriptionStore
  @Environment(\.navigate) private var navigate

  init(historyStore: HistoryStore, settingsStore: SettingsStore, transcriptionStore: TranscriptionStore) {
    self.historyStore = historyStore
    self.settingsStore = settingsStore
    self.transcriptionStore = transcriptionStore
  }

  private var tiles: [HomeTile] {
    [
      HomeTile(icon: recordingTileIcon, title: recordingTileTitle, action: .toggleRecording),
      HomeTile(icon: "plus.square.on.square", title: "Create a Mode", action: .createMode),
      HomeTile(icon: "square.stack.3d.up", title: "Manage Models", action: .manageModels),
      HomeTile(icon: "plus", title: "Add Shortcut", action: .addShortcut),
    ]
  }

  private var stats: HomeStats {
    HomeStats(records: historyStore.records)
  }

  private var todayItems: [HistoryItem] {
    Array(
      historyStore.records
        .filter { Calendar.current.isDateInToday($0.createdAt) }
        .sorted { $0.createdAt > $1.createdAt }
        .prefix(HomePaneMetrics.todayLimit)
        .map(HistoryItem.init(record:)))
  }

  private var recordingTileIcon: String {
    transcriptionStore.isRecording ? "stop.fill" : "record.circle"
  }

  private var recordingTileTitle: String {
    transcriptionStore.isRecording ? "Stop Recording" : "Start Recording"
  }

  var body: some View {
    VStack(spacing: 0) {
      Header {
        microphoneMenu
      }
      paneContent
    }
    .onAppear {
      historyStore.search("")
    }
  }

  private var paneContent: some View {
    Pane {
      statsSection
      quickActionsSection
      todaySection
    }
  }

  private var microphoneMenu: some View {
    HeaderMicrophoneMenu(store: settingsStore)
  }

  private var statsSection: some View {
    PaneSection(title: "All time") {
      Card {
        HStack(spacing: 0) {
          Stat(value: stats.averageSpeedValue, label: "Average speed")
          Stat(value: stats.wordsValue, label: "Words")
          Stat(value: stats.appsUsedValue, label: "Apps used")
          Stat(value: stats.timeSavedValue, label: "Saved all time", showsGear: true)
        }
      }
    }
  }

  private var quickActionsSection: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: HomePaneMetrics.tileMinimumWidth), spacing: 10)], spacing: 10) {
      ForEach(tiles) { tile in
        Tile(icon: tile.icon, title: tile.title) {
          perform(tile.action)
        }
      }
    }
  }

  private func perform(_ action: HomeTileAction) {
    switch action {
    case .toggleRecording:
      if transcriptionStore.isRecording {
        transcriptionStore.stopRecording()
      } else {
        transcriptionStore.startRecording()
      }
    case .createMode:
      navigate(.createMode)
    case .manageModels:
      navigate(.tab(.models))
    case .addShortcut:
      navigate(.tab(.configuration))
    }
  }

  private var todaySection: some View {
    PaneSection(title: "Today", trailing: "View all") {
      if todayItems.isEmpty {
        SettingsCard(dividerInset: 12) {
          InfoRow(
            icon: "text.bubble",
            title: "No recordings today",
            subtitle: "New dictations will appear here after they are saved."
          )
        }
      } else {
        VStack(spacing: HistoryMetrics.rowSpacing) {
          ForEach(todayItems) { item in
            HistoryRow(item: item) {
              navigate(.historyItem(item.id))
            }
          }
        }
      }
    }
  }

}

private enum HomePaneMetrics {
  static let todayLimit = 3
  static let tileMinimumWidth: CGFloat = 160
  static let previewWidth: CGFloat = 620
  static let previewHeight: CGFloat = 700
}

#Preview("Home") {
  @Previewable @State var store = AppPreviewState.makeStore()
  FloatingHost {
    HomePane(historyStore: store.history, settingsStore: store.settings, transcriptionStore: store.transcription)
      .frame(width: HomePaneMetrics.previewWidth, height: HomePaneMetrics.previewHeight)
      .background(Theme.windowBackground)
  }
}
