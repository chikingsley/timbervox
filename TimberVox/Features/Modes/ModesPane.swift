import SwiftUI

struct ModesPane: View {
  @State private var modeStore = ModeStore.shared
  @State private var transcriptionCatalog = TranscriptionModelCatalogStore.shared
  @State private var selectedModeID: String?
  @State private var pendingDeleteID: String?
  @State private var showsDeleteConfirmation = false

  var body: some View {
    VStack(spacing: 0) {
      if let selectedModeID, modeStore.mode(id: selectedModeID) != nil {
        ModeDetailHeader(
          modeID: selectedModeID,
          modeStore: modeStore,
          canDelete: modeStore.modes.count > 1,
          onDelete: { requestDelete(selectedModeID) },
          onBack: { self.selectedModeID = nil }
        )

        ModeDetailForm(
          modeID: selectedModeID,
          modeStore: modeStore,
          transcriptionCatalog: transcriptionCatalog
        )
      } else {
        AppPageHeader("Modes") {
          Button("Create mode", systemImage: "plus") {
            createMode()
          }
          .buttonStyle(.sc(.secondary, size: .sm))
        }

        ModeListView(
          modes: modeStore.modes,
          activeModeID: modeStore.activeModeID,
          transcriptionModels: transcriptionCatalog.models,
          languageModels: transcriptionCatalog.languageModels,
          onSelect: { selectedModeID = $0 },
          onCreate: createMode(preset:)
        )
      }
    }
    .task {
      await refreshCatalog()
    }
    .scAlertDialog(
      isPresented: $showsDeleteConfirmation,
      title: "Delete mode?",
      message: deleteMessage,
      confirmLabel: "Delete",
      role: .destructive,
      onConfirm: confirmDelete
    )
  }

  private var deleteMessage: String {
    guard let pendingDeleteID, let mode = modeStore.mode(id: pendingDeleteID) else {
      return "This mode will be removed permanently."
    }
    return "\u{201c}\(mode.name)\u{201d} will be removed permanently."
  }

  private func createMode() {
    let newID = modeStore.addMode()
    modeStore.updateMode(id: newID) {
      $0.name = "New Mode"
      $0.nameIsCustomized = true
      $0.textTransformPreset = .custom
      $0.iconSystemName = nil
    }
    normalizeMode(id: newID)
    selectedModeID = newID
  }

  private func createMode(preset: ModeTextTransformPreset) {
    let newID = modeStore.addMode()
    modeStore.updateMode(id: newID) {
      $0.name = preset.referenceLabel
      $0.nameIsCustomized = false
      $0.textTransformPreset = preset
      $0.iconSystemName = nil
      $0.textTransformContextOptions =
        preset == .custom ? .none : preset.usesAllAvailableContext ? .allAvailable : .none
      if preset == .custom {
        $0.customTextTransformInstructions = TextTransformPreset.defaultCustomInstructions
      }
    }
    normalizeMode(id: newID)
    selectedModeID = newID
  }

  private func requestDelete(_ id: String) {
    guard modeStore.modes.count > 1 else { return }
    pendingDeleteID = id
    showsDeleteConfirmation = true
  }

  private func confirmDelete() {
    guard let pendingDeleteID else { return }
    modeStore.deleteMode(id: pendingDeleteID)
    if selectedModeID == pendingDeleteID {
      selectedModeID = nil
    }
    self.pendingDeleteID = nil
  }

  private func normalizeModes() {
    for id in modeStore.modes.map(\.id) {
      normalizeMode(id: id)
    }
  }

  private func refreshCatalog() async {
    await transcriptionCatalog.refreshIfNeeded()
    normalizeModes()
  }

  private func normalizeMode(id: String) {
    guard let current = modeStore.mode(id: id) else { return }
    let normalized = transcriptionCatalog.normalized(current)
    guard normalized != current else { return }
    modeStore.updateMode(id: id) { $0 = normalized }
  }
}

private struct ModeDetailHeader: View {
  let modeID: String
  @Bindable var modeStore: ModeStore
  let canDelete: Bool
  let onDelete: () -> Void
  let onBack: () -> Void

  @Environment(\.theme) private var theme

  var body: some View {
    ZStack {
      HStack(spacing: AppSpacing.sm) {
        Image(systemName: mode?.resolvedIconSystemName ?? "mic.fill")
          .font(.system(size: 16, weight: .semibold))

        TextField("Mode name", text: nameBinding)
          .textFieldStyle(.plain)
          .font(.system(size: 14, weight: .semibold))
          .fixedSize(horizontal: true, vertical: false)
          .multilineTextAlignment(.center)
      }

      HStack(spacing: AppSpacing.xs) {
        Button(action: onBack) {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(.sc(.ghost, size: .iconSM))
        .accessibilityLabel("Back")

        Spacer(minLength: AppSpacing.md)

        if let mode {
          ShareLink(
            item: sharePayload(for: mode),
            subject: Text("TimberVox mode: \(mode.name)"),
            message: Text("Import this TimberVox mode configuration.")
          ) {
            Image(systemName: "square.and.arrow.up")
          }
          .buttonStyle(.sc(.ghost, size: .iconSM))
          .accessibilityLabel("Share mode")
        }

        Button(role: .destructive, action: onDelete) {
          Image(systemName: "trash")
        }
        .buttonStyle(.sc(.ghost, size: .iconSM))
        .disabled(!canDelete)
        .accessibilityLabel("Delete mode")
      }
    }
    .padding(.horizontal, AppSpacing.sm)
    .frame(height: AppLayout.headerHeight)
    .foregroundStyle(theme.foreground)
    .background(theme.background)
    .overlay(alignment: .bottom) {
      SCSeparator().opacity(0.7)
    }
  }

  private var mode: DictationMode? {
    modeStore.mode(id: modeID)
  }

  private var nameBinding: Binding<String> {
    Binding {
      modeStore.mode(id: modeID)?.name ?? "Mode"
    } set: { name in
      modeStore.updateMode(id: modeID) {
        $0.name = name
        $0.nameIsCustomized = true
      }
    }
  }

  private func sharePayload(for mode: DictationMode) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(mode), let json = String(data: data, encoding: .utf8) else {
      return mode.name
    }
    return json
  }
}

extension ModeTextTransformPreset {
  var referenceLabel: String {
    switch self {
    case .voiceToText: "Voice to Text"
    case .meeting: "Meeting Summary"
    default: label
    }
  }
}
