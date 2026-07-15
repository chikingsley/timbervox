import Foundation

enum TranscriptionRuntimeError: LocalizedError {
  case configuration(String)
  case emptyResult
  case jobFailed(String)
  case realtimeFailed(String)
  case realtimeFailedWithArtifact(String, TranscriptionArtifact)
  case timedOut
  case uploadFailed(String)

  var errorDescription: String? {
    switch self {
    case .configuration(let message):
      message
    case .emptyResult:
      "The transcription came back empty."
    case .jobFailed(let reason):
      "The server could not transcribe: \(reason)"
    case .realtimeFailed(let reason):
      "Realtime transcription failed: \(reason)"
    case .realtimeFailedWithArtifact(let reason, _):
      "Realtime transcription failed: \(reason)"
    case .timedOut:
      "Transcription timed out."
    case .uploadFailed(let reason):
      "Audio upload failed after retrying: \(reason)"
    }
  }

  var artifact: TranscriptionArtifact? {
    guard case .realtimeFailedWithArtifact(_, let artifact) = self else { return nil }
    return artifact
  }
}
