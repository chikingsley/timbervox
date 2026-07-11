import SwiftUI

struct PrototypeDictionaryPane: View {
  @State private var segment: DictionarySegment = .replacements
  @State private var searchText = ""
  @State private var scratchpadText = "Ok so uh I was testing deep gram against para keet on cloud flare"
  @State private var replacements = DictionaryReplacement.mock
  @State private var removals = DictionaryRemoval.mock
  @State private var vocabulary = DictionaryVocabTerm.mock
  @State private var newVocabText = ""

  var body: some View {
    VStack(spacing: 0) {
      Header {
        searchField
      } trailing: {
        addMenu
      }
      Pane {
        scratchpadCard

        segmentControl

        switch segment {
        case .replacements:
          replacementsSection
        case .removals:
          removalsSection
        case .vocabulary:
          vocabularySection
        }

        correctionLoopCard
      }
    }
  }

  private var searchField: some View {
    SearchField(placeholder: "Search the dictionary…", text: $searchText)
      .frame(maxWidth: .infinity)
  }

  private var addMenu: some View {
    Menu {
      Button("Add replacement") { addReplacement() }
      Button("Add removal") { addRemoval() }
      Button("Add term") { addTerm() }
    } label: {
      HStack(spacing: 5) {
        Image(systemName: "plus")
          .font(.system(size: 10, weight: .medium))
        Text("Add")
          .font(.system(size: 12))
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 9))
          .foregroundStyle(.tertiary)
      }
      .foregroundStyle(.secondary)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  private func addReplacement() {
    replacements.append(
      DictionaryReplacement(match: "misheard phrase", replacement: "correction", source: .manual)
    )
    withAnimation(.easeInOut(duration: 0.15)) { segment = .replacements }
  }

  private func addRemoval() {
    removals.append(DictionaryRemoval(pattern: "hmm+", note: "thinking sound"))
    withAnimation(.easeInOut(duration: 0.15)) { segment = .removals }
  }

  private func addTerm() {
    vocabulary.append(DictionaryVocabTerm(text: "New term"))
    withAnimation(.easeInOut(duration: 0.15)) { segment = .vocabulary }
  }

  private var query: String {
    searchText.trimmingCharacters(in: .whitespaces).lowercased()
  }

  private var filteredReplacementIDs: Set<UUID> {
    guard !query.isEmpty else { return Set(replacements.map(\.id)) }
    return Set(
      replacements
        .filter { $0.match.lowercased().contains(query) || $0.replacement.lowercased().contains(query) }
        .map(\.id)
    )
  }

  private var filteredRemovalIDs: Set<UUID> {
    guard !query.isEmpty else { return Set(removals.map(\.id)) }
    return Set(
      removals
        .filter { $0.pattern.lowercased().contains(query) || $0.note.lowercased().contains(query) }
        .map(\.id)
    )
  }

  private var filteredVocabulary: [DictionaryVocabTerm] {
    guard !query.isEmpty else { return vocabulary }
    return vocabulary.filter { $0.text.lowercased().contains(query) }
  }

  private var scratchpadCard: some View {
    PaneSection(title: "Try it out") {
      Card {
        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 8) {
            Image(systemName: "waveform")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
            TextField("Say something…", text: $scratchpadText)
              .textFieldStyle(.plain)
              .font(.system(size: 13))
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(Theme.fieldSurface, in: RoundedRectangle(cornerRadius: 8))

          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
              .font(.system(size: 10))
              .foregroundStyle(.tertiary)
            Text(previewText.isEmpty ? "Live preview appears here" : previewText)
              .font(.system(size: 13))
              .foregroundStyle(previewText.isEmpty ? .tertiary : .primary)
              .frame(maxWidth: .infinity, alignment: .leading)
            if !previewText.isEmpty {
              KeyChip("\(activeRuleCount) rules")
            }
          }
          .padding(.horizontal, 2)
        }
        .padding(12)
      }
    }
  }

  private var previewText: String {
    var output = scratchpadText
    for removal in removals where removal.isEnabled {
      output = output.replacingOccurrences(
        of: "\\b\(removal.pattern)\\b[,]?\\s?",
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
    }
    for replacement in replacements where replacement.isEnabled {
      output = output.replacingOccurrences(
        of: replacement.match,
        with: replacement.replacement,
        options: [.caseInsensitive]
      )
    }
    return
      output
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespaces)
  }

  private var activeRuleCount: Int {
    replacements.filter(\.isEnabled).count + removals.filter(\.isEnabled).count
  }

  private var segmentControl: some View {
    HStack(spacing: 2) {
      ForEach(DictionarySegment.allCases) { item in
        DictionarySegmentButton(
          title: item.title,
          count: count(for: item),
          isSelected: segment == item
        ) {
          withAnimation(.easeInOut(duration: 0.15)) { segment = item }
        }
      }
    }
    .padding(3)
    .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
  }

  private func count(for item: DictionarySegment) -> Int {
    switch item {
    case .replacements: filteredReplacementIDs.count
    case .removals: filteredRemovalIDs.count
    case .vocabulary: filteredVocabulary.count
    }
  }

  private var replacementsSection: some View {
    PaneSection(
      title: "Replacements",
      hint: "Applied to every transcript, right after transcription and before the text is pasted."
    ) {
      SettingsCard {
        ForEach($replacements) { $entry in
          if filteredReplacementIDs.contains(entry.id) {
            DictionaryReplacementRow(entry: $entry) {
              replacements.removeAll { $0.id == entry.id }
            }
          }
        }
        if filteredReplacementIDs.isEmpty {
          DictionaryNoMatchesRow(query: searchText)
        }
        DictionaryAddRow(label: "Add replacement", action: addReplacement)

      }
    }
  }

  private var removalsSection: some View {
    PaneSection(
      title: "Removals",
      hint: "Case-insensitive regular expressions matched against whole words, then stripped from the transcript."
    ) {
      SettingsCard {
        ForEach($removals) { $entry in
          if filteredRemovalIDs.contains(entry.id) {
            DictionaryRemovalRow(entry: $entry) {
              removals.removeAll { $0.id == entry.id }
            }
          }
        }
        if filteredRemovalIDs.isEmpty {
          DictionaryNoMatchesRow(query: searchText)
        }
        DictionaryAddRow(label: "Add removal pattern", action: addRemoval)

      }
    }
  }

  private var vocabularySection: some View {
    PaneSection(
      title: "Vocabulary",
      hint: "Names and jargon the recognizer should expect. These bias the speech model's decoding — no rewriting after the fact."
    ) {
      Card {
        VStack(alignment: .leading, spacing: 12) {
          if filteredVocabulary.isEmpty {
            Text("No terms match \u{201C}\(searchText)\u{201D}")
              .font(.system(size: 12))
              .foregroundStyle(.tertiary)
          } else {
            DictionaryChipFlow(spacing: 6) {
              ForEach(filteredVocabulary) { term in
                DictionaryVocabChip(term: term) {
                  vocabulary.removeAll { $0.id == term.id }
                }
              }
            }
          }

          SearchField(placeholder: "Add a term…", icon: "plus", text: $newVocabText)
            .onSubmit(addVocabTerm)
            .frame(maxWidth: 220)
        }
        .padding(12)
      }
    }
  }

  private func addVocabTerm() {
    let trimmed = newVocabText.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    vocabulary.append(DictionaryVocabTerm(text: trimmed))
    newVocabText = ""
  }

  private var correctionLoopCard: some View {
    Card {
      HStack(spacing: 12) {
        Image(systemName: "sparkles")
          .font(.system(size: 15))
          .foregroundStyle(Color.accentColor)
          .frame(width: 24)
        Text("Learn from recent dictations")
          .font(.system(size: 13, weight: .medium))
        InfoHint("Scans your last 20 transcripts for edits you made afterward and suggests replacements. Coming soon.")
        Spacer()
        Button("Scan now") {}
          .buttonStyle(.plain)
          .font(.system(size: 12, weight: .medium))
          .padding(.horizontal, 12)
          .padding(.vertical, 5)
          .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
      }
      .padding(12)
    }
  }
}

#Preview("Dictionary") {
  FloatingHost {
    PrototypeDictionaryPane()
      .frame(width: 620, height: 700)
      .background(Theme.windowBackground)
  }
}
