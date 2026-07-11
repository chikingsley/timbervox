import Foundation

/// What happens to other apps' sound while a dictation recording runs.
/// Mute and Lower volume change only the speakers: the system-audio process
/// tap receives audio before output volume applies, so capture is unaffected.
/// Pause stops known media players at the source, which also silences the
/// system-audio stream for modes that capture it.
enum PlaybackPolicy: String, CaseIterable, Codable, Identifiable, Sendable {
  case keepPlaying
  case lowerVolume
  case mute
  case pauseMedia

  var id: String { rawValue }

  var label: String {
    switch self {
    case .keepPlaying: "Keep playing"
    case .lowerVolume: "Lower volume"
    case .mute: "Mute"
    case .pauseMedia: "Pause media"
    }
  }
}
