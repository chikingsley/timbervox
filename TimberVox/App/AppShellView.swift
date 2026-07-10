import Inject
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
  let billing: SubscriptionController
  let permissions: PermissionCoordinator
  @State private var activeTab: ActiveTab? = .home
  @ObserveInjection var injection

  var body: some View {
    Group {
      if selectedTab == .modes {
        ModesPane(activeTab: $activeTab)
      } else {
        NavigationSplitView {
          AppSidebar(activeTab: $activeTab)
        } detail: {
          selectedDetail
        }
      }
    }
    .frame(minWidth: 1000, minHeight: 620)
    .enableInjection()
  }

  private var selectedTab: ActiveTab {
    activeTab ?? .home
  }

  @ViewBuilder private var selectedDetail: some View {
    switch selectedTab {
    case .home: HomePane(dictation: dictation)
    case .history: HistoryPane(dictation: dictation)
    case .settings:
      SettingsPane(dictation: dictation, billing: billing, permissions: permissions)
    case .modes:
      EmptyView()
    }
  }
}

struct AppSidebar: View {
  @Binding var activeTab: ActiveTab?

  var body: some View {
    List(selection: $activeTab) {
      ForEach(ActiveTab.allCases) { tab in
        Label(tab.label, systemImage: tab.icon)
          .tag(tab)
      }
    }
    .navigationTitle("TimberVox")
    .navigationSplitViewColumnWidth(min: 170, ideal: 184, max: 210)
  }
}
