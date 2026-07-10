import Inject
import SwiftUI

struct ModesPane: View {
  @Binding var activeTab: ActiveTab?
  @State private var modeStore = ModeStore.shared
  @State private var transcriptionCatalog = TranscriptionModelCatalogStore.shared
  @State private var selectedModeID: String?
  @ObserveInjection var injection

  var body: some View {
    NavigationSplitView {
      AppSidebar(activeTab: $activeTab)
    } content: {
      ModeListView(
        modes: modeStore.modes,
        activeModeID: modeStore.activeModeID,
        selectedModeID: $selectedModeID,
        onAdd: createMode
      )
      .navigationTitle("Modes")
      .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
    } detail: {
      if transcriptionCatalog.models.isEmpty {
        ContentUnavailableView {
          Label("Model Catalog Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(transcriptionCatalog.lastError ?? "The catalog did not contain any models.")
        } actions: {
          Button("Retry", systemImage: "arrow.clockwise") {
            Task { await refreshCatalog() }
          }
        }
      } else if let selectedModeID, modeStore.mode(id: selectedModeID) != nil {
        ModeDetailForm(
          modeID: selectedModeID,
          modeStore: modeStore,
          transcriptionCatalog: transcriptionCatalog,
          onDuplicate: duplicateSelectedMode,
          onDelete: deleteSelectedMode
        )
      } else {
        ContentUnavailableView(
          "Select a Mode",
          systemImage: "slider.horizontal.3",
          description: Text("Choose a mode or create a new one.")
        )
      }
    }
    .navigationSplitViewStyle(.balanced)
    .task {
      ensureSelection()
      await refreshCatalog()
      ensureSelection()
    }
    .onAppear(perform: ensureSelection)
    .enableInjection()
  }

  private func createMode() {
    let newID = modeStore.addMode(templateID: selectedModeID)
    normalizeMode(id: newID)
    selectedModeID = newID
  }

  private func deleteSelectedMode() {
    guard let selectedModeID else { return }
    modeStore.deleteMode(id: selectedModeID)
    self.selectedModeID = modeStore.modes.first?.id
  }

  private func duplicateSelectedMode() {
    guard let selectedModeID else { return }
    let newID = modeStore.duplicateMode(id: selectedModeID)
    normalizeMode(id: newID)
    self.selectedModeID = newID
  }

  private func ensureSelection() {
    guard selectedModeID.flatMap(modeStore.mode(id:)) == nil else { return }
    selectedModeID = modeStore.activeModeID
  }

  private func normalizeModes() {
    for id in modeStore.modes.map(\.id) {
      normalizeMode(id: id)
    }
  }

  private func refreshCatalog() async {
    await transcriptionCatalog.refresh()
    normalizeModes()
  }

  private func normalizeMode(id: String) {
    guard let current = modeStore.mode(id: id) else { return }
    let normalized = transcriptionCatalog.normalized(current)
    guard normalized != current else { return }
    modeStore.updateMode(id: id) { $0 = normalized }
  }
}
