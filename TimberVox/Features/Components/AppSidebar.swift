import SwiftUI

struct AppSidebar: View {
  @Binding var activeTab: ActiveTab?

  var body: some View {
    SCSidebarHeader {
      Color.clear.frame(height: 24)
    }

    SCSidebarContent {
      SCSidebarGroup {
        SCSidebarMenu {
          ForEach(ActiveTab.allCases) { tab in
            SCSidebarMenuItem {
              SCSidebarMenuButton(
                tab.label,
                systemImage: tab.icon,
                isActive: activeTab == tab
              ) {
                activeTab = tab
              }
              .accessibilityIdentifier("sidebar.\(tab.rawValue)")
            }
          }
        }
      }
    }
  }
}
