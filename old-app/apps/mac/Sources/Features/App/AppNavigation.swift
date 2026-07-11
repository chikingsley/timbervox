import SwiftUI

enum AppDestination: Equatable {
  case tab(ActiveTab)
  case historyItem(String)
  case createMode
}

private struct NavigateKey: EnvironmentKey {
  static let defaultValue: @MainActor @Sendable (AppDestination) -> Void = { _ in }
}

extension EnvironmentValues {
  var navigate: @MainActor @Sendable (AppDestination) -> Void {
    get { self[NavigateKey.self] }
    set { self[NavigateKey.self] = newValue }
  }
}
