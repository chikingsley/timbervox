import Foundation

enum HistoryRerunService {
  @MainActor
  static func rerun(
    audioURL: URL,
    route: TranscriptionRouteSpec,
    transcription: TranscriptionRuntime = .shared
  ) async throws -> TranscriptionArtifact {
    try await transcription.transcribeBatch(
      audioURL: audioURL,
      route: route
    )
  }
}
