import Foundation

enum FluidAudioModelRetentionOption: Int, CaseIterable, Identifiable, Sendable {
  case oneMinute = 1
  case fiveMinutes = 5
  case fifteenMinutes = 15
  case keepLoaded = 0

  var id: Int { rawValue }

  var label: String {
    switch self {
    case .oneMinute: "1 minute"
    case .fiveMinutes: "5 minutes"
    case .fifteenMinutes: "15 minutes"
    case .keepLoaded: "Keep loaded"
    }
  }
}

enum FluidAudioModelRetentionPreference {
  static let key = "voiceModelActiveDurationMinutes"
  static let defaultMinutes = FluidAudioModelRetentionOption.oneMinute.rawValue

  static var idleDuration: Duration? {
    let stored = UserDefaults.standard.object(forKey: key) as? Int
    let minutes = stored ?? defaultMinutes
    guard minutes > 0 else { return nil }
    return .seconds(minutes * 60)
  }
}
