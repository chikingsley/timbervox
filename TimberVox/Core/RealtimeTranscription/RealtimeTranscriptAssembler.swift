import Foundation

struct RealtimeTranscriptAssembler: Equatable, Sendable {
  private(set) var finalSegments: [String] = []
  private(set) var partialTranscript = ""
  private(set) var deltaTranscript = ""
  private(set) var completedTranscript: String?
  private(set) var errorMessage: String?
  private(set) var streamEnded = false
  private var lastFinalStart: Double?

  var text: String {
    if let completedTranscript {
      return completedTranscript
    }
    let stable = finalSegments.joined(separator: " ")
    let partial = partialTranscript.isEmpty ? deltaTranscript : partialTranscript
    if stable.isEmpty {
      return partial.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if partial.isEmpty {
      return stable.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return "\(stable) \(partial)".trimmingCharacters(in: .whitespacesAndNewlines)
  }

  mutating func consume(_ event: CloudRealtimeTranscriptionEvent) {
    switch event {
    case .interimTranscript(let text):
      partialTranscript = text
    case .transcriptDelta(let text):
      deltaTranscript += text
    case .committedTranscript(let text, let start):
      appendFinal(text, start: start)
    case .sessionCompleted(let text):
      completedTranscript = text.trimmingCharacters(in: .whitespacesAndNewlines)
      streamEnded = true
    case .sessionFailed(let message):
      errorMessage = message
      streamEnded = true
    default:
      break
    }
  }

  mutating func fail(_ message: String) {
    errorMessage = message
  }

  /// A provider flush can re-emit the last final for the same audio window;
  /// that duplicate shares the previous segment's start time. Identical text
  /// with a different start time is the speaker genuinely repeating themselves
  /// and must be kept.
  private mutating func appendFinal(_ text: String, start: Double?) {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return }
    if finalSegments.last != cleaned || lastFinalStart != start {
      finalSegments.append(cleaned)
      lastFinalStart = start
    }
    partialTranscript = ""
    deltaTranscript = ""
  }
}
