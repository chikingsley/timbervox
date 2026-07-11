import SwiftUI
import TimberVoxCore

extension AppearancePreference {
  var colorScheme: ColorScheme? {
    switch self {
    case .automatic: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

enum SidebarMode {
  case full, rail

  mutating func toggle() {
    self = self == .full ? .rail : .full
  }

  var width: CGFloat {
    self == .full ? Theme.sidebarWidth : Theme.railWidth
  }
}

struct AppShellView: View {
  @Bindable var store: AppStore
  @State private var sidebarMode: SidebarMode = .full
  @State private var pendingHistoryItemID: String?
  @State private var pendingCreateMode = false

  var body: some View {
    FloatingHost {
      HStack(spacing: 0) {
        AppSidebar(selectedTab: $store.activeTab, mode: sidebarMode)
          .frame(width: sidebarMode.width)
          .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.hairline).frame(width: 1)
          }

        detail
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .background(Theme.windowBackground)
      }
    }
    .ignoresSafeArea(.container, edges: .top)
    .preferredColorScheme(store.settings.timberVoxSettings.appearancePreference.colorScheme)
    .animation(.easeInOut(duration: 0.18), value: sidebarMode)
    .background(AppWindowConfigurator(sidebarMode: sidebarMode))
    .environment(\.toggleSidebar) {
      withAnimation(.easeInOut(duration: 0.18)) {
        sidebarMode.toggle()
      }
    }
    .environment(\.navigate) { destination in
      switch destination {
      case .tab(let tab):
        store.activeTab = tab
      case .historyItem(let id):
        pendingHistoryItemID = id
        store.activeTab = .history
      case .createMode:
        pendingCreateMode = true
        store.activeTab = .modes
      }
    }
  }

  @ViewBuilder private var detail: some View {
    switch store.activeTab {
    case .home: HomePane(historyStore: store.history, settingsStore: store.settings, transcriptionStore: store.transcription)
    case .modes: ModesPane(store: store.settings, createModeRequest: $pendingCreateMode)
    case .history: HistoryPane(store: store.history, deepLinkItemID: $pendingHistoryItemID)
    case .configuration:
      ConfigurationPane(
        store: store.settings,
        microphonePermission: store.microphonePermission,
        accessibilityPermission: store.accessibilityPermission,
        screenCapturePermission: store.screenCapturePermission
      )
    case .sound: SoundPane(store: store.settings)
    case .models: ModelLibraryPane(store: store.settings)
    }
  }
}

struct AppSidebar: View {
  @Binding var selectedTab: ActiveTab
  let mode: SidebarMode

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Color.clear.frame(height: 44)

      item(.home)

      groupGap

      ForEach(ActiveTab.libraryTop) { tab in
        item(tab)
      }

      if mode == .full {
        Text("Settings")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.tertiary)
          .padding(.horizontal, 12)
          .padding(.top, 14)
          .padding(.bottom, 4)
      } else {
        groupGap
      }

      ForEach(ActiveTab.settings) { tab in
        item(tab)
      }

      groupGap

      item(.history)

      Spacer()
    }
    .padding(.horizontal, 6)
    .frame(maxHeight: .infinity)
    .background(Theme.sidebarBackground)
  }

  private func item(_ tab: ActiveTab) -> some View {
    AppSidebarItem(tab: tab, isSelected: selectedTab == tab, mode: mode) { selectedTab = tab }
  }

  private var groupGap: some View {
    Color.clear.frame(height: 10)
  }
}

private struct AppSidebarItem: View {
  let tab: ActiveTab
  let isSelected: Bool
  let mode: SidebarMode
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 9) {
        IconTile(
          systemName: tab.icon,
          style: .colored(tab.iconColor),
          size: 22,
          isSelected: isSelected
        )
        if mode == .full {
          Text(tab.label)
            .font(.system(size: 13, weight: isSelected ? .medium : .regular))
          Spacer(minLength: 0)
        }
      }
      .padding(.horizontal, mode == .full ? 8 : 0)
      .frame(maxWidth: .infinity, alignment: mode == .full ? .leading : .center)
      .frame(height: mode == .full ? 32 : 36)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? Theme.selectionFill : (hovering ? Theme.hoverFill : .clear))
      )
      .contentShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .help(mode == .rail ? tab.label : "")
  }
}

private struct AppWindowConfigurator: NSViewRepresentable {
  let sidebarMode: SidebarMode

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      configure(view.window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    configure(nsView.window)
  }

  private func configure(_ window: NSWindow?) {
    guard let window else { return }
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = sidebarMode == .rail
  }
}
