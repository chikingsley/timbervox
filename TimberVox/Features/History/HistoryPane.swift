import AVFoundation
import AppKit
import Inject
import SwiftUI

struct HistoryPane: View {
  let dictation: DictationController
  @State private var query = ""
  @State private var modelFilter: String?
  @State private var items: [TranscriptRecord] = []
  @State private var selectedID: Int64?
  @State private var showDetails = false
  @State private var justCopied = false
  @State private var isRerunning = false
  @State private var rerunError: String?
  @State private var transcriptionCatalog = TranscriptionModelCatalogStore.shared
  @ObserveInjection var injection

  private var filtered: [TranscriptRecord] {
    guard let modelFilter else { return items }
    return items.filter { $0.model == modelFilter }
  }

  private var dayGroups: [(day: Date, records: [TranscriptRecord])] {
    let calendar = Calendar.current
    let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.createdAt) }
    return groups.keys.sorted(by: >).map { (day: $0, records: groups[$0] ?? []) }
  }

  private var selected: TranscriptRecord? {
    filtered.first { $0.id == selectedID }
  }

  private var selectedAudioURL: URL? {
    guard let path = selected?.audioPath, FileManager.default.fileExists(atPath: path) else {
      return nil
    }
    return URL(fileURLWithPath: path)
  }

  var body: some View {
    HStack(spacing: 0) {
      VStack(spacing: 0) {
        HStack(spacing: 4) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
          TextField("Search", text: $query)
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 7).fill(.quaternary.opacity(0.6)))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)

        Divider()

        List(selection: $selectedID) {
          ForEach(dayGroups, id: \.day) { group in
            Section(Self.dayLabel(group.day)) {
              ForEach(group.records) { item in
                VStack(alignment: .leading, spacing: 3) {
                  Text(item.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                  HStack(spacing: 8) {
                    Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                    Text(HomePane.formatDuration(item.durationSeconds))
                      .monospacedDigit()
                  }
                  .font(.caption)
                  .foregroundStyle(.secondary)
                }
                .tag(item.id ?? -1)
                .contextMenu {
                  Button("Copy") { Self.copy(item.text) }
                  Button("Delete", role: .destructive) { delete(item) }
                }
              }
            }
          }
        }
        .listStyle(.inset)
        .overlay {
          if filtered.isEmpty {
            ContentUnavailableView(
              query.isEmpty ? "No dictations yet" : "No matches",
              systemImage: "clock",
              description: Text(
                query.isEmpty ? "Dictations you make are saved here." : "Try a different search.")
            )
          }
        }
      }
      .frame(width: 260)

      Divider()

      Group {
        if let selected {
          TranscriptDetailView(
            item: selected,
            isRerunning: isRerunning,
            rerunError: rerunError
          )
          .id(selected.id)
        } else {
          ContentUnavailableView(
            "Select a dictation",
            systemImage: "text.quote",
            description: Text("The transcript and playback show here.")
          )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      if showDetails {
        Divider()
        detailsInspector
          .frame(width: 220)
          .transition(.move(edge: .trailing))
      }
    }
    .animation(.easeInOut(duration: 0.22), value: showDetails)
    .navigationTitle("History")
    .toolbar {
      ToolbarItemGroup {
        Menu {
          Button("All models") { modelFilter = nil }
          Divider()
          ForEach(Array(Set(items.map(\.model))).sorted(), id: \.self) { model in
            Button(model) { modelFilter = model }
          }
        } label: {
          Label(
            "Filter",
            systemImage: modelFilter == nil
              ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .help(modelFilter.map { "Showing \($0)" } ?? "Filter by model")

        Button(justCopied ? "Copied" : "Copy") {
          guard let selected else { return }
          Self.copy(selected.text)
          justCopied = true
          Task {
            try? await Task.sleep(for: .seconds(1.2))
            justCopied = false
          }
        }
        .disabled(selected == nil)
        .help("Copy the transcript")

        Menu("Re-transcribe") { rerunMenuItems }
          .disabled(selectedAudioURL == nil || isRerunning)
          .help(
            selected == nil
              ? "Select a dictation"
              : (selectedAudioURL == nil
                ? "Audio file is gone — can't re-transcribe" : "Re-run this audio with a model"))

        Menu("More") {
          if let selectedAudioURL {
            Button("Show in Finder") {
              NSWorkspace.shared.activateFileViewerSelecting([selectedAudioURL])
            }
          }
          Divider()
          Button("Delete", role: .destructive) {
            if let selected { delete(selected) }
          }
        }
        .disabled(selected == nil)
      }

      ToolbarItemGroup {
        Button("Details", systemImage: "sidebar.trailing") {
          showDetails.toggle()
        }
        .help(showDetails ? "Hide details" : "Show details")
      }
    }
    .task(id: dictation.lastTranscript) { reload() }
    .task(id: query) { reload() }
    .task { await transcriptionCatalog.refreshIfNeeded() }
    .enableInjection()
  }

  @ViewBuilder private var rerunMenuItems: some View {
    if transcriptionCatalog.batchModels.isEmpty {
      Button("No batch models") {}
        .disabled(true)
    } else {
      ForEach(transcriptionCatalog.batchModels) { model in
        if let route = model.batchRoute {
          Button(model.menuLabel) {
            rerun(route: route)
          }
        }
      }
    }
  }

  @ViewBuilder private var detailsInspector: some View {
    if let selected {
      Form {
        LabeledContent(
          "Created", value: selected.createdAt.formatted(date: .abbreviated, time: .shortened))
        LabeledContent("Model", value: selected.model)
        if let provider = selected.provider {
          LabeledContent("Provider", value: provider)
        }
        if let latency = selected.providerLatencyMs {
          LabeledContent("Latency", value: "\(Int(latency)) ms")
        }
        if let language = selected.language {
          LabeledContent("Language", value: language)
        }
        LabeledContent("Duration", value: HomePane.formatDuration(selected.durationSeconds))
        LabeledContent("Words", value: "\(selected.text.split(separator: " ").count)")
        if let path = selected.audioPath {
          LabeledContent("Audio", value: URL(fileURLWithPath: path).lastPathComponent)
        }
      }
      .formStyle(.grouped)
    } else {
      Text("Select a dictation")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func rerun(route: TranscriptionRouteSpec) {
    guard let source = selected, let audioURL = selectedAudioURL else { return }
    isRerunning = true
    rerunError = nil
    Task {
      do {
        let outcome = try await HistoryRerunService.rerun(audioURL: audioURL, route: route)
        let record = try TranscriptStore.shared.save(
          text: outcome.text,
          duration: source.durationSeconds,
          model: route.model,
          audioPath: source.audioPath,
          provider: outcome.provider,
          providerLatencyMs: outcome.providerLatencyMs,
          language: outcome.language
        )
        reload()
        selectedID = record.id
      } catch {
        rerunError = error.localizedDescription
      }
      isRerunning = false
    }
  }

  private func reload() {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    items =
      (try? trimmed.isEmpty
        ? TranscriptStore.shared.recent() : TranscriptStore.shared.search(trimmed)) ?? []
  }

  private func delete(_ item: TranscriptRecord) {
    try? TranscriptStore.shared.delete(id: item.id ?? -1)
    if selectedID == item.id { selectedID = nil }
    reload()
  }

  static func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  static func dayLabel(_ day: Date) -> String {
    if Calendar.current.isDateInToday(day) { return "Today" }
    if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
    return day.formatted(date: .abbreviated, time: .omitted)
  }
}

private struct TranscriptDetailView: View {
  let item: TranscriptRecord
  let isRerunning: Bool
  let rerunError: String?

  private var audioURL: URL? {
    guard let path = item.audioPath, FileManager.default.fileExists(atPath: path) else {
      return nil
    }
    return URL(fileURLWithPath: path)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView {
        Text(item.text)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
      }

      if isRerunning {
        HStack(spacing: 8) {
          ProgressView().controlSize(.small)
          Text("Re-transcribing…").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
      }
      if let rerunError {
        Text(rerunError)
          .font(.callout)
          .foregroundStyle(.red)
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
      }

      if let audioURL {
        Divider()
        PlaybackBar(url: audioURL)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
      }
    }
  }
}

private struct PlaybackBar: View {
  let url: URL

  @State private var player: AVAudioPlayer?
  @State private var isPlaying = false
  @State private var position: TimeInterval = 0

  var body: some View {
    HStack(spacing: 10) {
      Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill") {
        togglePlayback()
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)

      Text(HomePane.formatDuration(position))
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)

      Slider(
        value: Binding(
          get: { position },
          set: { newValue in
            position = newValue
            player?.currentTime = newValue
          }
        ),
        in: 0...max(player?.duration ?? 0, 0.1)
      )

      Text(HomePane.formatDuration(player?.duration ?? 0))
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
    .task(id: url) {
      player = try? AVAudioPlayer(contentsOf: url)
      isPlaying = false
      position = 0
      while !Task.isCancelled {
        if let player, isPlaying {
          position = player.currentTime
          if !player.isPlaying {
            isPlaying = false
            position = 0
          }
        }
        try? await Task.sleep(for: .milliseconds(250))
      }
    }
    .onDisappear {
      player?.stop()
    }
  }

  private func togglePlayback() {
    guard let player else { return }
    if isPlaying {
      player.pause()
      isPlaying = false
    } else {
      player.play()
      isPlaying = true
    }
  }
}
