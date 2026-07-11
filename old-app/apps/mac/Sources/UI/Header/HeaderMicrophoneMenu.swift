import SwiftUI

struct HeaderMicrophoneMenu: View {
  private static let systemDefaultMicrophoneID = "system-default-input"

  @Bindable var store: SettingsStore

  var body: some View {
    OptionMenu(
      selection: microphoneSelection,
      options: microphoneOptions,
      width: HeaderMicrophoneMenuMetrics.width,
      panelWidth: HeaderMicrophoneMenuMetrics.panelWidth
    )
    .fixedSize()
    .onAppear {
      store.loadAvailableInputDevices()
    }
  }

  private var microphoneSelection: Binding<String> {
    Binding(
      get: { store.timberVoxSettings.selectedMicrophoneID ?? Self.systemDefaultMicrophoneID },
      set: { selectedID in
        store.timberVoxSettings.selectedMicrophoneID =
          selectedID == Self.systemDefaultMicrophoneID ? nil : selectedID
      }
    )
  }

  private var microphoneOptions: [MenuOption<String>] {
    var options = [
      MenuOption(
        value: Self.systemDefaultMicrophoneID,
        label: defaultMicrophoneLabel,
        systemImage: "headphones"
      )
    ]

    options.append(
      contentsOf: store.availableInputDevices.map { device in
        MenuOption(value: device.id, label: device.name, systemImage: "headphones")
      }
    )

    if let selectedID = store.timberVoxSettings.selectedMicrophoneID,
      !options.contains(where: { $0.value == selectedID })
    {
      options.append(
        MenuOption(
          value: selectedID,
          label: "Unavailable microphone",
          systemImage: "headphones",
          accessoryText: "Missing"
        )
      )
    }

    return options
  }

  private var defaultMicrophoneLabel: String {
    if let name = store.defaultInputDeviceName, !name.isEmpty {
      return "System Default (\(name))"
    }
    return "System Default"
  }
}

private enum HeaderMicrophoneMenuMetrics {
  static let width: CGFloat = 230
  static let panelWidth: CGFloat = 262
}
