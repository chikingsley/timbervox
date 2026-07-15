import AppKit
import GRDB
import SwiftUI

struct HistoryPane: View {
  @Binding var requestedSelectionID: Int64?
  @State private var query = ""
  @State private var pageLimit = HistoryPresentationPolicy.pageSize
  @State private var detailSearchQuery = ""
  @State private var items: [TranscriptRecord] = []
  @State private var totalItemCount = 0
  @State private var expandedID: Int64?
  @State private var scrollTargetID: Int64?
  @State private var detailID: Int64?
  @State private var detailsID: Int64?
  @State private var pendingDeleteID: Int64?
  @State private var transcriptModes: [Int64: HistoryTranscriptViewMode] = [:]
  @State private var detailPlayer = HistoryAudioPlayer()
  @State private var isRerunning = false
  @State private var rerunError: String?
  @State private var transcriptionCatalog = TranscriptionModelCatalogStore.shared
  @Environment(\.theme) private var theme
  private var dayGroups: [(day: Date, records: [TranscriptRecord])] {
    let groups = Dictionary(grouping: items) {
      Calendar.current.startOfDay(for: $0.createdAt)
    }
    return groups.keys.sorted(by: >).map { day in
      (day: day, records: groups[day] ?? [])
    }
  }
  private var detailRecord: TranscriptRecord? {
    items.first { $0.id == detailID }
  }
  private var detailsRecord: TranscriptRecord? {
    items.first { $0.id == detailsID }
  }
  var body: some View {
    VStack(spacing: 0) {
      if let detailRecord {
        AppSearchHeader(
          placeholder: "Search transcript",
          query: $detailSearchQuery
        ) {
          Button {
            detailID = nil
            detailSearchQuery = ""
            rerunError = nil
          } label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 13, weight: .semibold))
          }
          .buttonStyle(.sc(.ghost, size: .iconSM))
          .accessibilityLabel("Back to history")
        }
        detail(record: detailRecord)
      } else {
        AppSearchHeader(placeholder: "Search history", query: $query)
        historyList
      }
    }
    .scSheet(isPresented: detailsSheetBinding) {
      if let detailsRecord {
        HistoryDetailsSheet(
          record: detailsRecord,
          modelDisplayName: transcriptionCatalog.displayName(forRouteModel: detailsRecord.model)
        ) {
          detailsID = nil
        }
      }
    }
    .foregroundStyle(theme.foreground)
    .background(theme.background)
    .accessibilityIdentifier("history.content")
    .scAlertDialog(
      isPresented: deleteAlertBinding,
      title: "Delete recording?",
      message: "The transcript will be removed from History. Its audio file is not deleted.",
      confirmLabel: "Delete",
      role: .destructive,
      onConfirm: deletePendingRecord
    )
    .task(id: reloadKey) {
      if !trimmedQuery.isEmpty {
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
      }
      await observePage()
    }
    .onChange(of: query) { _, _ in
      pageLimit = HistoryPresentationPolicy.pageSize
    }
    .task { await transcriptionCatalog.refreshIfNeeded() }
    .onDisappear(perform: resetTransientState)
  }
}
private extension HistoryPane {
  private var historyList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 18) {
          if items.isEmpty {
            SCEmpty(
              query.isEmpty ? "No dictations yet" : "No matches",
              systemImage: query.isEmpty ? "waveform" : "magnifyingglass",
              description: query.isEmpty
                ? "Dictations you make are saved here."
                : "Try a different search."
            )
            .frame(maxWidth: .infinity, minHeight: 280)
          } else {
            ForEach(dayGroups, id: \.day) { group in
              VStack(alignment: .leading, spacing: 8) {
                Text(HistoryPresentationPolicy.dayLabel(group.day))
                  .font(.system(size: 12, weight: .medium))
                  .foregroundStyle(theme.mutedForeground)
                  .padding(.horizontal, 4)

                LazyVStack(spacing: 8) {
                  ForEach(group.records) { record in
                    card(for: record)
                  }
                }
              }
            }

            historyListFooter
          }
        }
        .appContentColumn(topInset: AppSpacing.lg, bottomInset: AppSpacing.xl)
      }
      .scrollIndicators(.hidden)
      .onChange(of: scrollTargetID) { _, targetID in
        guard let targetID else { return }
        withAnimation(.easeOut(duration: 0.15)) {
          proxy.scrollTo(targetID, anchor: .top)
        }
        scrollTargetID = nil
      }
    }
  }
  private var historyListFooter: some View {
    VStack(spacing: AppSpacing.sm) {
      Text("Showing \(items.count) of \(totalItemCount) \(totalItemCount == 1 ? "dictation" : "dictations")")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(theme.mutedForeground)

      if items.count < totalItemCount {
        Button("Load more") {
          pageLimit += HistoryPresentationPolicy.pageSize
        }
        .buttonStyle(.sc(.outline, size: .sm))
      }
    }
    .frame(maxWidth: .infinity)
  }
  private func card(for record: TranscriptRecord) -> some View {
    let id = record.id ?? -1
    let isExpanded = expandedID == id
    return HistoryRecordCard(
      record: record,
      isExpanded: isExpanded,
      isDimmed: expandedID != nil && !isExpanded,
      transcriptMode: transcriptMode(for: record),
      onToggleExpanded: {
        if HistoryPresentationPolicy.shouldOpenInDetail(record) {
          detailID = id
          detailSearchQuery = ""
          expandedID = nil
          loadFullRecord(id: id)
          return
        }
        withAnimation(.easeOut(duration: 0.15)) {
          expandedID = isExpanded ? nil : id
        }
        if !isExpanded {
          scrollTargetID = id
          loadFullRecord(id: id)
        }
      },
      onOpenDetail: {
        detailID = id
        detailSearchQuery = ""
        expandedID = nil
        loadFullRecord(id: id)
      },
      onSetTranscriptMode: { mode in
        transcriptModes[id] = mode
      },
      onCopy: {
        Self.copy(record.transcriptText(for: transcriptMode(for: record)))
      },
      onShowDetails: {
        detailsID = id
        loadFullRecord(id: id)
      },
      onDelete: {
        pendingDeleteID = id
      }
    )
  }
  private func detail(record: TranscriptRecord) -> some View {
    HistoryDetailPlaybackView(
      record: record,
      transcriptMode: transcriptMode(for: record),
      searchQuery: detailSearchQuery,
      player: detailPlayer,
      isRerunning: isRerunning,
      rerunError: rerunError,
      onSetTranscriptMode: { mode in
        transcriptModes[record.id ?? -1] = mode
      },
      onCopy: {
        Self.copy(record.transcriptText(for: transcriptMode(for: record)))
      },
      onShowDetails: {
        detailsID = record.id
        if let id = record.id { loadFullRecord(id: id) }
      },
      onDelete: {
        pendingDeleteID = record.id
      },
      contextAction: {
        HistoryRerunMenu(
          models: transcriptionCatalog.batchModels,
          isRerunning: isRerunning,
          audioAvailable: record.audioPath.map(FileManager.default.fileExists(atPath:)) ?? false
        ) { route in
          rerun(record: record, route: route)
        }
      }
    )
  }
  private var reloadKey: HistoryReloadKey {
    HistoryReloadKey(query: query, pageLimit: pageLimit)
  }
  private var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func observePage() async {
    do {
      var isFirstValue = true
      for try await page in try TranscriptStore.shared.observeHistoryPage(
        matching: trimmedQuery,
        limit: pageLimit
      ) {
        items = page.records
        totalItemCount = page.totalCount
        pruneHiddenSelections()
        refreshActiveFullRecords()
        guard isFirstValue else { continue }
        isFirstValue = false
        applyRequestedSelection()
        await Task.yield()
        NavigationPerformance.historyContentReady(
          itemCount: items.count,
          queryMilliseconds: page.queryMilliseconds
        )
      }
    } catch {
      guard !Task.isCancelled else { return }
      TimberVoxLog.persistence.error(
        "History observation failed: \(error.localizedDescription)"
      )
    }
  }

  private func pruneHiddenSelections() {
    let visibleIDs = Set(items.compactMap(\.id))
    if let expandedID, !visibleIDs.contains(expandedID) { self.expandedID = nil }
    if let detailID, !visibleIDs.contains(detailID) { self.detailID = nil }
    if let detailsID, !visibleIDs.contains(detailsID) { self.detailsID = nil }
  }

  /// List rows arrive without their JSON payloads; the expanded card, detail
  /// view, and details sheet need the full record, fetched here on demand.
  private func loadFullRecord(id: Int64) {
    Task {
      guard
        let full = try? await TranscriptStore.shared.record(id: id),
        let index = items.firstIndex(where: { $0.id == id })
      else { return }
      items[index] = full
    }
  }

  private func refreshActiveFullRecords() {
    for id in Set([expandedID, detailID, detailsID].compactMap { $0 }) {
      loadFullRecord(id: id)
    }
  }

  private func applyRequestedSelection() {
    guard let requestedSelectionID else { return }
    defer { self.requestedSelectionID = nil }
    guard let record = items.first(where: { $0.id == requestedSelectionID }) else { return }
    if HistoryPresentationPolicy.shouldOpenInDetail(record) {
      detailID = requestedSelectionID
      expandedID = nil
    } else {
      expandedID = requestedSelectionID
      scrollTargetID = requestedSelectionID
    }
    loadFullRecord(id: requestedSelectionID)
  }

  private func resetTransientState() {
    expandedID = nil
    detailID = nil
    detailsID = nil
    pendingDeleteID = nil
    detailSearchQuery = ""
    detailPlayer.stop()
    rerunError = nil
    requestedSelectionID = nil
  }

  private func rerun(record: TranscriptRecord, route: TranscriptionRouteSpec) {
    guard
      let audioPath = record.audioPath,
      FileManager.default.fileExists(atPath: audioPath)
    else {
      return
    }
    isRerunning = true
    rerunError = nil
    Task {
      do {
        let artifact = try await HistoryRerunService.rerun(
          audioURL: URL(fileURLWithPath: audioPath),
          route: route
        )
        let saved = try await Task.detached {
          try TranscriptStore.shared.save(
            text: artifact.displayText,
            artifact: artifact,
            duration: record.durationSeconds,
            modeID: record.modeID,
            modeName: record.modeName,
            audioPath: record.audioPath,
            sourceApplicationName: record.sourceApplicationName,
            sourceApplicationBundleIdentifier: record.sourceApplicationBundleIdentifier
          )
        }.value
        items.insert(saved, at: 0)
        totalItemCount += 1
        detailID = saved.id
      } catch {
        rerunError = error.localizedDescription
      }
      isRerunning = false
    }
  }

  private func transcriptMode(for record: TranscriptRecord) -> HistoryTranscriptViewMode {
    let id = record.id ?? -1
    let requested = transcriptModes[id] ?? record.defaultTranscriptMode
    return record.availableTranscriptModes.contains(requested)
      ? requested
      : record.defaultTranscriptMode
  }

  private var deleteAlertBinding: Binding<Bool> {
    Binding(
      get: { pendingDeleteID != nil },
      set: { isPresented in
        if !isPresented { pendingDeleteID = nil }
      }
    )
  }

  private var detailsSheetBinding: Binding<Bool> {
    Binding(
      get: { detailsID != nil },
      set: { isPresented in
        if !isPresented { detailsID = nil }
      }
    )
  }

  private func deletePendingRecord() {
    guard let pendingDeleteID else { return }
    if expandedID == pendingDeleteID { expandedID = nil }
    if detailID == pendingDeleteID { detailID = nil }
    if detailsID == pendingDeleteID { detailsID = nil }
    self.pendingDeleteID = nil
    Task {
      try? await TranscriptStore.shared.delete(id: pendingDeleteID)
    }
  }

  private static func copy(_ text: String) {
    guard !text.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }
}
