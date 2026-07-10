import AppKit
import Inject
import SwiftUI

struct PrototypeHistoryView: View {
  @Binding var destination: PrototypeDestination?
  enum Filter: String, CaseIterable, Identifiable {
    case all = "All"
    case delivered = "Delivered"
    case issues = "Issues"

    var id: String { rawValue }
  }

  @State private var items = PrototypeHistoryItem.samples
  @State private var selectedID = PrototypeHistoryItem.samples.first?.id
  @State private var query = ""
  @State private var filter = Filter.all
  @State private var showsInspector = false
  @State private var justCopied = false
  @ObserveInjection var injection

  private var filteredItems: [PrototypeHistoryItem] {
    items.filter { item in
      let matchesQuery = query.isEmpty || item.deliveredText.localizedStandardContains(query)
      let matchesFilter =
        switch filter {
        case .all: true
        case .delivered: item.status == .delivered
        case .issues: item.status != .delivered
        }
      return matchesQuery && matchesFilter
    }
  }

  private var selectedItem: PrototypeHistoryItem? { items.first { $0.id == selectedID } }

  var body: some View {
    PrototypeCollectionLayout(destination: $destination) {
      historyList
    } detail: {
      Group {
        if let selectedItem {
          PrototypeHistoryDetail(item: selectedItem)
        } else {
          ContentUnavailableView(
            "Select a Dictation", systemImage: "text.quote",
            description: Text("Delivered text and playback appear here."))
        }
      }
    }
    .inspector(isPresented: $showsInspector) {
      PrototypeHistoryInspector(item: selectedItem)
        .inspectorColumnWidth(min: 220, ideal: 250, max: 300)
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
          Picker("Status", selection: $filter) {
            ForEach(Filter.allCases) { value in
              Text(value.rawValue).tag(value)
            }
          }
        }
        Button {
          copySelectedItem()
        } label: {
          Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
            .foregroundStyle(justCopied ? Color.green : Color.primary)
            .frame(width: 18, height: 18)
        }
        .accessibilityLabel(justCopied ? "Copied" : "Copy")
        .disabled(selectedItem == nil)
        .help(justCopied ? "Copied" : "Copy dictation")
        Menu {
          ForEach(PrototypeMode.samples) { mode in
            Button {
              reprocess(with: mode)
            } label: {
              Label(mode.name, systemImage: mode.icon)
            }
          }
        } label: {
          PrototypeReprocessLabel()
        }
        .disabled(selectedItem?.status != .delivered)
        .help("Reprocess with a mode")
        Button("Inspector", systemImage: "sidebar.trailing") {
          showsInspector.toggle()
        }
        .labelStyle(.iconOnly)
        .help(showsInspector ? "Hide Inspector" : "Show Inspector")
        Button(role: .destructive) {
          deleteSelectedItem()
        } label: {
          Label("Delete", systemImage: "trash")
        }
        .labelStyle(.iconOnly)
        .help("Delete dictation")
        .disabled(selectedItem == nil)
      }
    }
    .enableInjection()
  }

  private var historyList: some View {
    VStack(spacing: 0) {
      PrototypeInlineSearchField(text: $query, prompt: "Search dictations")
        .padding(8)

      Divider()

      List(selection: $selectedID) {
        Section("Today") {
          ForEach(filteredItems.filter { Calendar.current.isDateInToday($0.createdAt) }) { item in
            PrototypeHistoryRow(item: item)
              .tag(item.id)
              .contextMenu {
                Button("Copy") {}
                Button("Rerun") {}
                Divider()
                Button("Delete", role: .destructive) { delete(item.id) }
              }
          }
        }

        Section("Earlier") {
          ForEach(filteredItems.filter { !Calendar.current.isDateInToday($0.createdAt) }) { item in
            PrototypeHistoryRow(item: item)
              .tag(item.id)
          }
        }
      }
      .overlay {
        if filteredItems.isEmpty {
          ContentUnavailableView.search(text: query)
        }
      }
    }
    .navigationTitle("History")
  }

  private func delete(_ id: UUID) {
    items.removeAll { $0.id == id }
    selectedID = items.first?.id
  }

  private func deleteSelectedItem() {
    guard let selectedID else { return }
    delete(selectedID)
  }

  private func copySelectedItem() {
    guard let selectedItem else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(selectedItem.deliveredText, forType: .string)
    justCopied = true
    Task {
      try? await Task.sleep(for: .seconds(1.2))
      justCopied = false
    }
  }

  private func reprocess(with mode: PrototypeMode) {
    guard selectedItem != nil else { return }
    // The connected prototype demonstrates mode selection only. Production
    // History will route this action through the real dictation workflow.
    _ = mode
  }
}

private struct PrototypeInlineSearchField: NSViewRepresentable {
  @Binding var text: String
  let prompt: String

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  func makeNSView(context: Context) -> NSSearchField {
    let searchField = NSSearchField()
    searchField.placeholderString = prompt
    searchField.sendsSearchStringImmediately = true
    searchField.delegate = context.coordinator
    return searchField
  }

  func updateNSView(_ searchField: NSSearchField, context: Context) {
    if searchField.stringValue != text {
      searchField.stringValue = text
    }
  }

  final class Coordinator: NSObject, NSSearchFieldDelegate {
    @Binding private var text: String

    init(text: Binding<String>) {
      _text = text
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let searchField = notification.object as? NSSearchField else { return }
      text = searchField.stringValue
    }
  }
}

private struct PrototypeReprocessLabel: View {
  var body: some View {
    ZStack {
      Image(systemName: "arrow.counterclockwise")
      Image(systemName: "sparkles")
        .font(.system(size: 7, weight: .bold))
        .offset(x: 1)
    }
    .frame(width: 18, height: 18)
    .accessibilityLabel("Reprocess")
  }
}

private struct PrototypeHistoryRow: View {
  let item: PrototypeHistoryItem

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(item.deliveredText)
          .lineLimit(2)
        Spacer(minLength: 6)
        if item.status != .delivered {
          Image(systemName: item.status == .failed ? "exclamationmark.triangle.fill" : "waveform.slash")
            .foregroundStyle(item.status == .failed ? .red : .secondary)
            .help(item.status.rawValue)
        }
      }
      HStack {
        Text(item.createdAt.formatted(date: .omitted, time: .shortened))
        Text("·")
        Text(item.application)
        Text("·")
        Text(PrototypeFormat.duration(item.duration))
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, 3)
  }
}

private struct PrototypeHistoryDetail: View {
  let item: PrototypeHistoryItem
  @State private var showsRawText = false

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if item.status == .delivered {
            Text(item.deliveredText)
              .font(.title3)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            ContentUnavailableView(
              item.status.rawValue,
              systemImage: item.status == .failed ? "exclamationmark.triangle" : "waveform.slash",
              description: Text(item.deliveredText))
          }

          if let rawText = item.rawText {
            DisclosureGroup("Original transcription", isExpanded: $showsRawText) {
              Text(rawText)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, 6)
            }
          }
        }
        .padding(24)
      }

    }
  }
}

private struct PrototypeHistoryInspector: View {
  let item: PrototypeHistoryItem?

  var body: some View {
    if let item {
      Form {
        Section("Source") {
          LabeledContent("Application", value: item.application)
          LabeledContent("Mode", value: item.mode)
          LabeledContent("Created", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        Section("Transcription") {
          LabeledContent("Model", value: item.model)
          LabeledContent("Provider", value: item.provider)
          LabeledContent("Language", value: "English")
          LabeledContent("Duration", value: PrototypeFormat.duration(item.duration))
          LabeledContent("Latency", value: "640 ms")
        }
        Section("Files") {
          LabeledContent("Audio", value: "Available")
          Button("Show in Finder") {}
        }
      }
      .formStyle(.grouped)
    } else {
      ContentUnavailableView("No Selection", systemImage: "sidebar.trailing")
    }
  }
}

enum PrototypeFormat {
  static func duration(_ interval: TimeInterval) -> String {
    let totalSeconds = Int(interval)
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
  }
}

#Preview("History") {
  PrototypeHistoryView(destination: .constant(.history))
    .frame(width: 1_120, height: 720)
}
