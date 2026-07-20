import SwiftUI

enum ActiveTab: String, CaseIterable, Identifiable {
  case home
  case modes
  case history
  case settings

  var id: String { rawValue }

  var label: String {
    switch self {
    case .home: "Home"
    case .modes: "Modes"
    case .history: "History"
    case .settings: "Settings"
    }
  }

  var icon: String {
    switch self {
    case .home: "house"
    case .modes: "slider.horizontal.3"
    case .history: "clock"
    case .settings: "gearshape"
    }
  }
}

struct AppShellView: View {
  let dictation: DictationController
  let permissions: PermissionCoordinator
  @State private var activeTab: ActiveTab? = .home
  @State private var selectedHistoryID: Int64?

  var body: some View {
    SCSidebarLayout(
      collapsible: .icon,
      persistenceKey: "timbervox.sidebar.open",
      expandedWidth: 184,
      collapsedWidth: 56
    ) {
      AppSidebar(activeTab: $activeTab)
    } detail: {
      selectedPage
    }
    .frame(minWidth: 1000, minHeight: 620)
    .ignoresSafeArea(.container, edges: .top)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      AppDownloadStatusBar {
        selectedHistoryID = nil
        activeTab = .modes
      }
    }
  }

  @ViewBuilder private var selectedPage: some View {
    if selectedTab == .history || selectedTab == .modes {
      selectedDetail
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      VStack(spacing: 0) {
        AppPageHeader(title: selectedTab.label)
        selectedDetail
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  private var selectedTab: ActiveTab {
    activeTab ?? .home
  }

  @ViewBuilder private var selectedDetail: some View {
    switch selectedTab {
    case .home:
      HomePane(
        dictation: dictation,
        activeTab: $activeTab,
        selectedHistoryID: $selectedHistoryID
      )
    case .history:
      HistoryPane(requestedSelectionID: $selectedHistoryID)
    case .settings:
      SettingsPane(dictation: dictation, permissions: permissions)
    case .modes:
      ModesPane()
    }
  }

}
