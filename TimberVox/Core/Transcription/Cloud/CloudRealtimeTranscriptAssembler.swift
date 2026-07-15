import Foundation

struct CloudRealtimeTranscriptAssembler: Equatable, Sendable {
  private(set) var finalSegments: [String] = []
  private(set) var committedSegments: [TranscriptionTimedText] = []
  private(set) var committedSpeakerTurns: [TranscriptionTimedText] = []
  private(set) var committedWords: [TranscriptionTimedText] = []
  private(set) var partialTranscript = ""
  private(set) var deltaTranscript = ""
  private(set) var completedTranscript: String?
  private(set) var errorMessage: String?
  private(set) var streamEnded = false
  private(set) var terminalArtifact: TranscriptionArtifact?
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
    case .interimTranscript(let payload):
      partialTranscript = payload.text
    case .transcriptDelta(let payload):
      deltaTranscript += payload.text
    case .committedTranscript(let payload):
      appendFinal(payload)
    case .sessionCompleted(let artifact):
      terminalArtifact = artifact
      completedTranscript = artifact.displayText
      streamEnded = true
    case .sessionFailed(let message, let artifact):
      terminalArtifact = artifact
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
  private mutating func appendFinal(_ payload: CloudRealtimeTranscriptPayload) {
    let cleaned = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return }
    let start = payload.segments.first?.startSeconds
    if finalSegments.last != cleaned || lastFinalStart != start {
      finalSegments.append(cleaned)
      committedSegments.append(contentsOf: payload.segments)
      committedSpeakerTurns.append(contentsOf: payload.speakerTurns)
      committedWords.append(contentsOf: payload.words)
      lastFinalStart = start
    }
    partialTranscript = ""
    deltaTranscript = ""
  }

  func artifact() throws -> TranscriptionArtifact {
    guard let terminalArtifact else {
      throw TranscriptionRuntimeError.realtimeFailed(
        "Realtime session ended without a terminal artifact."
      )
    }
    return terminalArtifact
  }
}
