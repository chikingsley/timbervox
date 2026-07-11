import SwiftUI

enum ActiveTab: String, CaseIterable, Identifiable {
  case home, modes, history
  case configuration, sound, models

  var id: String { rawValue }

  var label: String {
    switch self {
    case .home: "Home"
    case .modes: "Modes"
    case .history: "History"
    case .configuration: "Configuration"
    case .sound: "Sound"
    case .models: "Model library"
    }
  }

  var icon: String {
    switch self {
    case .home: "house"
    case .modes: "mic.fill"
    case .history: "fossil.shell.fill"
    case .configuration: "slider.horizontal.3"
    case .sound: "speaker.wave.2.fill"
    case .models: "square.stack.3d.up"
    }
  }

  var iconColor: Color {
    switch self {
    case .home: Color(hex: Shadcn.orange500)
    case .modes: Color(hex: Shadcn.blue500)
    case .history: Color(hex: Shadcn.violet500)
    case .configuration: Color(hex: Shadcn.neutral500)
    case .sound: Color(hex: Shadcn.neutral500)
    case .models: Color(hex: Shadcn.neutral600)
    }
  }

  static let libraryTop: [ActiveTab] = [.modes]
  static let settings: [ActiveTab] = [.configuration, .sound, .models]

  var debugName: String { rawValue }
}
