import SwiftUI

/// Alternate history prototype: one roof for dictations and imported
/// transcriptions, with different row/detail treatments per item type.
struct PrototypeHistoryPaneV2: View {
  private enum Route: Equatable {
    case list
    case detail(HistoryItemV2)
  }

  @State private var route: Route = .list
  @State private var scope: HistoryScopeV2 = .all
  @State private var appFilter: HistoryAppV2? = nil
  @State private var searchText = ""

  private var filteredItems: [HistoryItemV2] {
    HistoryItemV2.samples.filter { item in
      let scopeMatch = scope == .all || item.scope == scope
      let appMatch = appFilter == nil || item.app == appFilter
      let searchMatch = searchText.isEmpty
        || item.title.localizedCaseInsensitiveContains(searchText)
        || item.preview.localizedCaseInsensitiveContains(searchText)
        || item.app.rawValue.localizedCaseInsensitiveContains(searchText)
      return scopeMatch && appMatch && searchMatch
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      ProtoHeader(control: route == .list ? .sidebarToggle : .back {
        withAnimation(.easeInOut(duration: 0.18)) {
          route = .list
        }
      }) {
        if route == .list {
          Text("History")
            .font(.system(size: 13, weight: .semibold))
        } else if case .detail(let item) = route {
          Text(item.title)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
        }
      } trailing: {
        if route == .list {
          historySearch
        } else {
          Button {} label: {
            Image(systemName: "doc.on.doc")
              .font(.system(size: 13, weight: .semibold))
              .frame(width: 28, height: 28)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }

      switch route {
      case .list:
        listPage
          .transition(.opacity.combined(with: .move(edge: .leading)))
      case .detail(let item):
        detailPage(item)
          .transition(.opacity.combined(with: .move(edge: .trailing)))
      }
    }
    .animation(.easeInOut(duration: 0.18), value: route)
  }

  private var historySearch: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
      TextField("Search history", text: $searchText)
        .textFieldStyle(.plain)
        .font(.system(size: 12))
      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 9)
    .frame(width: 230, height: 30)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
  }

  private var listPage: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 10) {
        Picker("", selection: $scope) {
          ForEach(HistoryScopeV2.allCases) { scope in
            Text(scope.label).tag(scope)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 282)

        Menu {
          Button("All apps") { appFilter = nil }
          Divider()
          ForEach(HistoryAppV2.allCases) { app in
            Button {
              appFilter = app
            } label: {
              Label(app.rawValue, systemImage: app.icon)
            }
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: appFilter?.icon ?? "square.grid.2x2")
            Text(appFilter?.rawValue ?? "Apps")
            Image(systemName: "chevron.up.chevron.down")
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(.tertiary)
          }
          .font(.system(size: 12, weight: .semibold))
          .padding(.horizontal, 10)
          .frame(height: 30)
          .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
        }
        .menuStyle(.borderlessButton)
        Spacer()
      }

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          ForEach(["Today", "Yesterday", "Apr 3, 2026"], id: \.self) { day in
            let items = filteredItems.filter { $0.day == day }
            if !items.isEmpty {
              VStack(alignment: .leading, spacing: 10) {
                Text(day)
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(.secondary)
                VStack(spacing: 8) {
                  ForEach(items) { item in
                    HistoryRowV2(item: item) {
                      withAnimation(.easeInOut(duration: 0.18)) {
                        route = .detail(item)
                      }
                    }
                  }
                }
              }
            }
          }
        }
        .padding(.bottom, 18)
      }
      .scrollIndicators(.never)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder private func detailPage(_ item: HistoryItemV2) -> some View {
    if item.scope == .dictations {
      DictationDetailV2(item: item)
    } else {
      TranscriptionDetailV2(item: item)
    }
  }
}

private enum HistoryScopeV2: String, CaseIterable, Identifiable {
  case all, dictations, transcriptions

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all: "All"
    case .dictations: "Dictations"
    case .transcriptions: "Files"
    }
  }
}

private enum HistoryAppV2: String, CaseIterable, Identifiable {
  case xcode = "Xcode"
  case mail = "Mail"
  case notes = "Notes"
  case zoom = "Zoom"
  case safari = "Safari"
  case finder = "Finder"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .xcode: "hammer.fill"
    case .mail: "envelope.fill"
    case .notes: "note.text"
    case .zoom: "video.fill"
    case .safari: "safari.fill"
    case .finder: "folder.fill"
    }
  }

  var tint: Color {
    switch self {
    case .xcode: .blue
    case .mail: .cyan
    case .notes: .yellow
    case .zoom: .indigo
    case .safari: .blue
    case .finder: .orange
    }
  }
}

private struct HistoryItemV2: Identifiable, Equatable {
  let id: String
  let scope: HistoryScopeV2
  let app: HistoryAppV2
  let title: String
  let preview: String
  let day: String
  let time: String
  let duration: String
  let mode: String
  let speakers: Int?

  static let samples: [HistoryItemV2] = [
    HistoryItemV2(id: "dictation-xcode-1", scope: .dictations, app: .xcode, title: "MacWhisper", preview: "The history is just not great for me. It's ugly and it's over complicated. I want the context, the app, the time, and the length, but not a pile of metadata in the way.", day: "Today", time: "6:14 PM", duration: "0:38", mode: "Vibe Code", speakers: nil),
    HistoryItemV2(id: "dictation-xcode-2", scope: .dictations, app: .xcode, title: "Xcode note", preview: "Add a separate one so we can go back and forth and compare. Let's go ahead and do that.", day: "Today", time: "5:34 PM", duration: "0:07", mode: "Default", speakers: nil),
    HistoryItemV2(id: "dictation-mail", scope: .dictations, app: .mail, title: "Release follow-up", preview: "Hey, just following up on the release notes. I left two small comments, otherwise it looks ready to ship.", day: "Today", time: "1:20 PM", duration: "0:09", mode: "Email", speakers: nil),
    HistoryItemV2(id: "file-unit-14", scope: .transcriptions, app: .finder, title: "Pimsleur French I - Unit 14", preview: "This is Unit 14 de Pimsleur's Speak and Read Essential French 1. Ecoutez cette conversation francaise. Un monsieur americain veut acheter un journal.", day: "Apr 3, 2026", time: "6:07 PM", duration: "26:59", mode: "Parakeet v3", speakers: 5),
    HistoryItemV2(id: "file-meeting", scope: .transcriptions, app: .zoom, title: "Design review - sidebar and history", preview: "Decisions around one History roof, separating dictations from file transcriptions, and moving detailed metadata into an inspector.", day: "Yesterday", time: "3:44 PM", duration: "42:18", mode: "Meeting Notes", speakers: 4),
  ]
}

private struct HistoryRowV2: View {
  let item: HistoryItemV2
  let open: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: open) {
      if item.scope == .dictations {
        dictationRow
      } else {
        transcriptionCard
      }
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }

  private var dictationRow: some View {
    HStack(alignment: .top, spacing: 12) {
      HistoryAppIconV2(app: item.app)
      VStack(alignment: .leading, spacing: 5) {
        Text(item.preview)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(2)
        HStack(spacing: 6) {
          Text(item.app.rawValue)
          Text(item.time)
          Text(item.duration)
          Text(item.mode)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      }
      Spacer()
      HistoryRowActionsV2()
        .opacity(hovering ? 1 : 0)
    }
    .padding(.vertical, 7)
  }

  private var transcriptionCard: some View {
    HStack(alignment: .top, spacing: 12) {
      HistoryAppIconV2(app: item.app)
      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text(item.title)
            .font(.system(size: 13, weight: .semibold))
          Text(item.time)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          Spacer()
          if let speakers = item.speakers {
            Text("\(speakers) speakers")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.secondary)
          }
        }
        Text(item.preview)
          .font(.system(size: 13))
          .lineLimit(2)
        HStack(spacing: 8) {
          ProtoKbd(item.duration)
          ProtoKbd(item.mode)
        }
      }
    }
    .padding(14)
    .background(.white.opacity(hovering ? 0.11 : 0.075), in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
    )
  }
}

private struct HistoryAppIconV2: View {
  let app: HistoryAppV2

  var body: some View {
    Image(systemName: app.icon)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 26, height: 26)
      .background(app.tint.gradient, in: RoundedRectangle(cornerRadius: 7))
  }
}

private struct HistoryRowActionsV2: View {
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "play.fill")
      Image(systemName: "doc.on.doc")
      Image(systemName: "trash")
    }
    .font(.system(size: 11, weight: .semibold))
    .foregroundStyle(.secondary)
  }
}

private struct DictationDetailV2: View {
  let item: HistoryItemV2

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(item.preview)
        .font(.system(size: 15, weight: .semibold))
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 8) {
        ProtoKbd(item.app.rawValue)
        ProtoKbd(item.time)
        ProtoKbd(item.duration)
        ProtoKbd(item.mode)
      }
      Spacer()
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

private struct TranscriptionDetailV2: View {
  let item: HistoryItemV2

  var body: some View {
    HStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          ForEach(transcriptLines, id: \.time) { line in
            HStack(alignment: .top, spacing: 18) {
              Text(line.speaker)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(line.color)
                .frame(width: 78, alignment: .trailing)
              Text(line.text)
                .font(.system(size: 15, weight: .semibold))
                .lineSpacing(5)
              Spacer()
              Text(line.time)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(28)
      }
      .scrollIndicators(.never)

      VStack(alignment: .leading, spacing: 14) {
        Text("Inspector")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
        inspectorRow("Model", item.mode)
        inspectorRow("Language", "French")
        inspectorRow("Duration", item.duration)
        inspectorRow("Speakers", "\(item.speakers ?? 0)")
        Divider()
        Text("People")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
        ForEach(["Speaker 1", "Speaker 2", "Speaker 3"], id: \.self) { speaker in
          HStack {
            Circle().fill(Color.blue.opacity(0.8)).frame(width: 8, height: 8)
            Text(speaker).font(.system(size: 12, weight: .semibold))
          }
        }
        Spacer()
      }
      .padding(16)
      .frame(width: 190)
      .background(.black.opacity(0.12))
      .overlay(alignment: .leading) {
        Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
      }
    }
  }

  private var transcriptLines: [(speaker: String, text: String, time: String, color: Color)] {
    [
      ("Speaker 1", "This is Unit 14 de Pimsleur's Speak and Read Essential French 1.", "00:00", .red),
      ("Speaker 1", "Ecoutez cette conversation francaise.", "00:04", .red),
      ("Speaker 2", "Oui, monsieur.", "00:30", .cyan),
      ("Speaker 1", "Voila.", "00:35", .red),
      ("Speaker 2", "Merci. Je vous dois combien?", "00:38", .cyan),
    ]
  }

  private func inspectorRow(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 12, weight: .semibold))
      Spacer()
      Text(value)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }
}

#Preview("History V2") {
  PrototypeHistoryPaneV2()
    .frame(width: 640, height: 680)
    .background(PrototypeTheme.windowBackground)
}
