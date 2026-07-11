import SwiftUI

enum HeaderControl {
  case sidebarToggle
  case back(() -> Void)
  case none
}

private struct ToggleSidebarKey: EnvironmentKey {
  static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
  var toggleSidebar: @MainActor @Sendable () -> Void {
    get { self[ToggleSidebarKey.self] }
    set { self[ToggleSidebarKey.self] = newValue }
  }
}

struct Header<Leading: View, Trailing: View>: View {
  var control: HeaderControl = .sidebarToggle
  @ViewBuilder var leading: Leading
  @ViewBuilder var trailing: Trailing
  @Environment(\.toggleSidebar) private var toggleSidebar

  var body: some View {
    HStack(spacing: 10) {
      controlView
      leading
      Spacer(minLength: 8)
      trailing
    }
    .padding(.leading, 10)
    .padding(.trailing, 14)
    .frame(height: Theme.headerHeight)
    .overlay(alignment: .bottom) {
      Rectangle().fill(Theme.hairline).frame(height: 1)
    }
  }

  @ViewBuilder private var controlView: some View {
    switch control {
    case .sidebarToggle:
      Button(action: toggleSidebar) {
        Image(systemName: "sidebar.leading")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    case .back(let action):
      Button(action: action) {
        Image(systemName: "chevron.left")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    case .none:
      EmptyView()
    }
  }
}

extension Header where Leading == EmptyView {
  init(control: HeaderControl = .sidebarToggle, @ViewBuilder _ trailing: () -> Trailing) {
    self.control = control
    leading = EmptyView()
    self.trailing = trailing()
  }
}

extension Header where Leading == EmptyView, Trailing == EmptyView {
  init(control: HeaderControl = .sidebarToggle) {
    self.control = control
    leading = EmptyView()
    trailing = EmptyView()
  }
}
