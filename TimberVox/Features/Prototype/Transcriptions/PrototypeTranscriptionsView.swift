import Inject
import SwiftUI

struct PrototypeTranscriptionsView: View {
  @Binding var destination: PrototypeDestination?
  @State private var transcriptions = PrototypeTranscription.samples
  @State private var selectedID = PrototypeTranscription.samples.first?.id
  @State private var query = ""
  @State private var statusFilter: PrototypeTranscription.Status?
  @State private var showsInspector = false
  @ObserveInjection var injection

  private var filtered: [PrototypeTranscription] {
    transcriptions.filter { item in
      let matchesQuery = query.isEmpty || item.title.localizedStandardContains(query)
      return matchesQuery && (statusFilter == nil || item.status == statusFilter)
    }
  }

  private var selected: PrototypeTranscription? { transcriptions.first { $0.id == selectedID } }

  var body: some View {
    PrototypeCollectionLayout(destination: $destination) {
      transcriptionList
    } detail: {
      Group {
        if let selected {
          PrototypeTranscriptEditor(transcription: binding(for: selected.id))
        } else {
          ContentUnavailableView(
            "Select a Transcription", systemImage: "doc.text",
            description: Text("The timed transcript and playback appear here."))
        }
      }
      .toolbar { detailToolbar }
    }
    .inspector(isPresented: $showsInspector) {
      PrototypeTranscriptionInspector(transcription: selected)
        .inspectorColumnWidth(min: 220, ideal: 250, max: 300)
    }
    .navigationTitle(selectedTitle)
    .enableInjection()
  }

  private var selectedTitle: Binding<String> {
    guard let selectedID, transcriptions.contains(where: { $0.id == selectedID }) else {
      return .constant("Transcriptions")
    }
    return binding(for: selectedID).title
  }

  private var transcriptionList: some View {
    List(selection: $selectedID) {
      ForEach(filtered) { item in
        PrototypeTranscriptionRow(item: item)
          .tag(item.id)
      }
    }
    .searchable(text: $query, prompt: "Search transcriptions")
    .overlay {
      if filtered.isEmpty {
        ContentUnavailableView.search(text: query)
      }
    }
    .toolbar { collectionToolbar }
  }

  @ToolbarContentBuilder private var collectionToolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Button("Import", systemImage: "square.and.arrow.down", action: importFile)
      Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
        Button("All Statuses") { statusFilter = nil }
        Divider()
        ForEach(PrototypeTranscription.Status.allCases, id: \.self) { status in
          Button(status.rawValue) { statusFilter = status }
        }
      }
    }
  }

  @ToolbarContentBuilder private var detailToolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Menu("Export", systemImage: "square.and.arrow.up") {
        Button("Plain Text") {}
        Button("Markdown") {}
        Divider()
        Button("SRT Captions") {}
        Button("WebVTT Captions") {}
        Button("JSON") {}
      }
      .disabled(selected?.status != .complete)
      Button("Inspector", systemImage: "sidebar.trailing") { showsInspector.toggle() }
        .labelStyle(.iconOnly)
        .help(showsInspector ? "Hide Inspector" : "Show Inspector")
      Button(role: .destructive, action: deleteSelected) {
        Label("Delete", systemImage: "trash")
      }
      .labelStyle(.iconOnly)
      .help("Delete transcription")
      .disabled(selected == nil)
    }
  }

  private func binding(for id: UUID) -> Binding<PrototypeTranscription> {
    Binding(
      get: { transcriptions.first { $0.id == id } ?? PrototypeTranscription.samples[0] },
      set: { updated in
        guard let index = transcriptions.firstIndex(where: { $0.id == id }) else { return }
        transcriptions[index] = updated
      })
  }

  private func importFile() {
    let item = PrototypeTranscription(
      id: UUID(), title: "New recording.wav", status: .queued, duration: 0, date: .now,
      speakers: 0, segments: [])
    transcriptions.insert(item, at: 0)
    selectedID = item.id
  }

  private func deleteSelected() {
    guard let selectedID else { return }
    transcriptions.removeAll { $0.id == selectedID }
    self.selectedID = transcriptions.first?.id
  }
}

private struct PrototypeTranscriptionRow: View {
  let item: PrototypeTranscription

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(item.title)
        .lineLimit(1)
      HStack {
        Label(item.status.rawValue, systemImage: statusImage)
          .foregroundStyle(statusColor)
        Spacer()
        Text(PrototypeFormat.duration(item.duration))
        Text(item.date.formatted(date: .abbreviated, time: .omitted))
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }

  private var statusImage: String {
    switch item.status {
    case .complete: "checkmark.circle.fill"
    case .processing: "gearshape.2"
    case .queued: "clock"
    case .failed: "exclamationmark.triangle.fill"
    }
  }

  private var statusColor: Color {
    switch item.status {
    case .complete: .green
    case .processing: .blue
    case .queued: .secondary
    case .failed: .red
    }
  }
}

private struct PrototypeTranscriptEditor: View {
  @Binding var transcription: PrototypeTranscription
  @State private var selectedSegmentID: UUID?

  var body: some View {
    if transcription.status == .complete {
      List(selection: $selectedSegmentID) {
        ForEach($transcription.segments) { $segment in
          PrototypeTranscriptSegmentRow(segment: $segment)
            .tag(segment.id)
        }
      }
      .listStyle(.inset)
    } else {
      processingState
    }
  }

  private var processingState: some View {
    ContentUnavailableView {
      Label(
        transcription.status.rawValue,
        systemImage: transcription.status == .failed ? "exclamationmark.triangle" : "gearshape.2")
    } description: {
      Text(
        transcription.status == .failed
          ? "Review the error and retry with another model."
          : "The source media is safe while TimberVox prepares the transcript.")
    } actions: {
      if transcription.status == .failed {
        Button("Retry") { transcription.status = .processing }
      } else if transcription.status == .queued {
        Button("Start Processing") { transcription.status = .processing }
      } else {
        ProgressView()
      }
    }
  }
}

private struct PrototypeTranscriptSegmentRow: View {
  @Binding var segment: PrototypeTranscriptSegment

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        TextField("Speaker", text: $segment.speaker)
          .textFieldStyle(.plain)
          .fontWeight(.semibold)
        Text(PrototypeFormat.duration(segment.timestamp))
          .font(.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      .frame(width: 100, alignment: .leading)

      TextEditor(text: $segment.text)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 44)
    }
    .padding(.vertical, 5)
  }
}

private struct PrototypeTranscriptionInspector: View {
  let transcription: PrototypeTranscription?

  var body: some View {
    if let transcription {
      Form {
        Section("Source Media") {
          LabeledContent("File", value: transcription.title)
          LabeledContent("Duration", value: PrototypeFormat.duration(transcription.duration))
          LabeledContent("Speakers", value: "\(transcription.speakers)")
          Button("Show in Finder") {}
        }
        Section("Latest Run") {
          LabeledContent("Status", value: transcription.status.rawValue)
          LabeledContent("Model", value: "Nova 3")
          LabeledContent("Provider", value: "Deepgram")
          LabeledContent("Language", value: "English")
          Button("Run Again…") {}
        }
        Section("Artifacts") {
          LabeledContent("Plain text", value: "Ready")
          LabeledContent("SRT", value: "Ready")
          LabeledContent("WebVTT", value: "Ready")
        }
      }
      .formStyle(.grouped)
    }
  }
}

#Preview("Transcriptions") {
  PrototypeTranscriptionsView(destination: .constant(.transcriptions))
    .frame(width: 1_120, height: 720)
}
