import Foundation

struct HistoryRerunOutcome {
  var text: String
  var provider: String?
  var providerLatencyMs: Double?
  var language: String?
}

enum HistoryRerunService {
  static func rerun(
    audioURL: URL,
    route: TranscriptionRouteSpec
  ) async throws -> HistoryRerunOutcome {
    switch route.executor {
    case .cloud:
      let outcome = try await CloudBatchTranscriptionClient.production.transcribe(
        wavAt: audioURL,
        model: route.model
      )
      return HistoryRerunOutcome(
        text: outcome.text,
        provider: outcome.provider,
        providerLatencyMs: outcome.providerLatencyMs,
        language: outcome.language
      )
    case .local(let localRoute):
      let start = Date.now
      let text = try await LocalBatchTranscriptionClient.shared.transcribe(
        wavAt: audioURL,
        route: localRoute
      )
      return HistoryRerunOutcome(
        text: text,
        provider: route.provider,
        providerLatencyMs: Date.now.timeIntervalSince(start) * 1_000,
        language: nil
      )
    }
  }
}
