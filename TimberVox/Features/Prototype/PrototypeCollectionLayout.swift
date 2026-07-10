import SwiftUI

struct PrototypeCollectionLayout<Collection: View, Detail: View>: View {
  @Binding private var destination: PrototypeDestination?
  private let collection: Collection
  private let detail: Detail

  init(
    destination: Binding<PrototypeDestination?>,
    @ViewBuilder collection: () -> Collection,
    @ViewBuilder detail: () -> Detail
  ) {
    _destination = destination
    self.collection = collection()
    self.detail = detail()
  }

  var body: some View {
    NavigationSplitView {
      PrototypeSidebar(destination: $destination)
    } content: {
      collection
        .navigationSplitViewColumnWidth(
          min: PrototypeLayout.collectionWidth,
          ideal: PrototypeLayout.collectionWidth,
          max: PrototypeLayout.collectionWidth)
    } detail: {
      detail
    }
    .navigationSplitViewStyle(.balanced)
  }
}

struct PrototypeSimpleLayout<Content: View>: View {
  @Binding private var destination: PrototypeDestination?
  private let content: Content

  init(
    destination: Binding<PrototypeDestination?>,
    @ViewBuilder content: () -> Content
  ) {
    _destination = destination
    self.content = content()
  }

  var body: some View {
    NavigationSplitView {
      PrototypeSidebar(destination: $destination)
    } detail: {
      content
    }
    .navigationSplitViewStyle(.balanced)
  }
}

private struct PrototypeSidebar: View {
  @Binding var destination: PrototypeDestination?

  var body: some View {
    List(selection: $destination) {
      Section {
        destinationRow(.home)
        destinationRow(.modes)
        destinationRow(.history)
      }

      Section("Library") {
        destinationRow(.transcriptions)
        destinationRow(.meetings)
      }

      Section("Automation") {
        destinationRow(.commands)
      }

      Section {
        destinationRow(.settings)
      }
    }
    .navigationTitle("TimberVox")
    .toolbar(removing: .sidebarToggle)
    .navigationSplitViewColumnWidth(
      min: PrototypeLayout.sidebarWidth,
      ideal: PrototypeLayout.sidebarWidth,
      max: PrototypeLayout.sidebarWidth)
  }

  private func destinationRow(_ value: PrototypeDestination) -> some View {
    Label(value.title, systemImage: value.systemImage)
      .tag(value)
  }
}

enum PrototypeLayout {
  static let sidebarWidth = 184.0
  static let collectionWidth = 300.0
  static let windowWidth = 1_080.0
  static let windowHeight = 700.0
}
