import Foundation

@testable import TimberVox

enum TestTranscriptionArtifact {
  static func make(
    text: String = "test transcript",
    model: String = "test-model",
    segments: [TranscriptionTimedText] = [],
    words: [TranscriptionTimedText] = []
  ) -> TranscriptionArtifact {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    return TranscriptionArtifact(
      content: content(segments: segments, words: words),
      language: TranscriptionLanguage(confidence: nil, detected: "en", requested: "en"),
      metrics: metrics,
      provenance: provenance(model: model, now: now),
      providerCapture: TranscriptionProviderCapture(
        metadata: [:],
        response: TranscriptionProviderResponse(
          mediaType: "application/json",
          payload: [:]
        )
      ),
      schemaVersion: TranscriptionArtifact.currentSchemaVersion,
      text: text,
      warnings: []
    )
  }

  private static func content(
    segments: [TranscriptionTimedText],
    words: [TranscriptionTimedText]
  ) -> TranscriptionContent {
    TranscriptionContent(
      audioEvents: TranscriptionCollection(availability: .unsupported, source: nil, items: []),
      segments: TranscriptionCollection(
        availability: segments.isEmpty ? .providerOmitted : .available,
        source: segments.isEmpty ? nil : .provider,
        items: segments
      ),
      speakerTurns: TranscriptionCollection(availability: .unsupported, source: nil, items: []),
      tokens: TranscriptionCollection(availability: .unsupported, source: nil, items: []),
      words: TranscriptionCollection(
        availability: words.isEmpty ? .providerOmitted : .available,
        source: words.isEmpty ? nil : .provider,
        items: words
      )
    )
  }

  private static var metrics: TranscriptionMetrics {
    TranscriptionMetrics(
      audioDurationSeconds: 1,
      decoderSeconds: nil,
      encoderSeconds: nil,
      firstResultLatencyMs: nil,
      gpuUtilization: nil,
      normalizationLatencyMs: nil,
      peakMemoryMB: nil,
      preprocessorSeconds: nil,
      processingSeconds: 0.5,
      providerLatencyMs: nil,
      queueDelayMs: nil,
      realtimeSpeedFactor: 2,
      tokensPerSecond: nil,
      usage: TranscriptionUsage(inputTokens: nil, outputTokens: nil, totalTokens: nil),
      wallLatencyMs: 500
    )
  }

  private static func provenance(model: String, now: Date) -> TranscriptionProvenance {
    TranscriptionProvenance(
      completedAt: now.addingTimeInterval(1),
      executor: .local,
      libraryName: "Test",
      libraryVersion: "1",
      model: model,
      provider: "test",
      providerRequestID: nil,
      runID: "test-run",
      startedAt: now,
      transport: .batch,
      upstreamModel: model
    )
  }
}
