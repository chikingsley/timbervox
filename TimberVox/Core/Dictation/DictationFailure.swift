import Foundation

enum DictationFailureCode: String, Codable, Equatable, Sendable {
  case authentication
  case billing
  case configuration
  case network
  case noSpeech = "no_speech"
  case provider
  case rateLimited = "rate_limited"
  case recording
  case textProcessing = "text_processing"
  case timedOut = "timed_out"
  case unknown
  case upload
}

struct DictationFailure: Codable, Equatable, Sendable {
  var code: DictationFailureCode
  var message: String

  static func transcription(_ error: Error) -> Self {
    if let runtimeError = error as? TranscriptionRuntimeError {
      switch runtimeError {
      case .emptyResult:
        return noSpeech
      case .configuration:
        return failure(.configuration, error)
      case .timedOut:
        return failure(.timedOut, error)
      case .uploadFailed:
        return failure(.upload, error)
      case .jobFailed, .realtimeFailed, .realtimeFailedWithArtifact:
        return failure(.provider, error)
      }
    }
    return classified(error, defaultCode: .provider)
  }

  static func textProcessing(_ error: Error) -> Self {
    classified(error, defaultCode: .textProcessing)
  }

  static func recording(_ error: Error) -> Self {
    classified(error, defaultCode: .recording)
  }

  static func recording(message: String) -> Self {
    DictationFailure(code: .recording, message: message)
  }

  private static let noSpeech = DictationFailure(
    code: .noSpeech,
    message: "No voice was detected."
  )

  private static func classified(
    _ error: Error,
    defaultCode: DictationFailureCode
  ) -> Self {
    if let apiError = error as? APIConnectorError {
      switch apiError {
      case .httpStatus(401), .httpStatus(403):
        return failure(.authentication, error)
      case .httpStatus(402):
        return failure(.billing, error)
      case .httpStatus(429):
        return failure(.rateLimited, error)
      default:
        break
      }
    }
    if let urlError = error as? URLError {
      let code: DictationFailureCode = urlError.code == .timedOut ? .timedOut : .network
      return failure(code, error)
    }
    return failure(defaultCode, error)
  }

  private static func failure(
    _ code: DictationFailureCode,
    _ error: Error
  ) -> Self {
    DictationFailure(code: code, message: error.localizedDescription)
  }
}
