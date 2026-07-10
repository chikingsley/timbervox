import Inject
import SwiftUI

struct TimberVoxPrototype: View {
  @State private var destination: PrototypeDestination? = .home
  @State private var showsSetupAssistant = false
  @ObserveInjection var injection

  private var selectedDestination: PrototypeDestination { destination ?? .home }

  var body: some View {
    Group {
      switch selectedDestination {
      case .modes:
        PrototypeModesView(destination: $destination)
      case .history:
        PrototypeHistoryView(destination: $destination)
      case .transcriptions:
        PrototypeTranscriptionsView(destination: $destination)
      case .meetings:
        PrototypeMeetingsView(destination: $destination)
      case .commands:
        PrototypeCommandsView(destination: $destination)
      case .home, .settings:
        PrototypeSimpleLayout(destination: $destination) {
          simpleDestinationView(selectedDestination)
        }
      }
    }
    .frame(
      minWidth: PrototypeLayout.windowWidth,
      idealWidth: PrototypeLayout.windowWidth,
      minHeight: PrototypeLayout.windowHeight,
      idealHeight: PrototypeLayout.windowHeight
    )
    .background(PrototypeWindowConfiguration())
    .sheet(isPresented: $showsSetupAssistant) {
      PrototypeOnboardingView {
        showsSetupAssistant = false
      }
    }
    .enableInjection()
  }

  @ViewBuilder private func simpleDestinationView(_ value: PrototypeDestination) -> some View {
    switch value {
    case .home:
      PrototypeHomeView(navigate: navigate)
    case .settings:
      PrototypeSettingsView { showsSetupAssistant = true }
    case .modes, .history, .transcriptions, .meetings, .commands:
      EmptyView()
    }
  }

  private func navigate(to value: PrototypeDestination) {
    destination = value
  }
}

#Preview("Connected App Prototype") {
  TimberVoxPrototype()
}
