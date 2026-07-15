@preconcurrency import FluidAudio
import Foundation

struct FluidAudioRealtimeArtifactInput {
  var text: String
  var timings: [TokenTiming]
  var route: LocalTranscriptionRouteID
  var requestedLanguage: String?
  var detectedLanguage: String?
  var providerMetadata: [String: TranscriptionJSONValue]
  var receivedSampleCount: Int
  var startedAt: Date
  var firstPartialAt: Date?
  var completedAt: Date
}

enum FluidAudioRealtimeArtifactBuilder {
  static func make(
    _ input: FluidAudioRealtimeArtifactInput
  ) -> TranscriptionArtifact {
    TranscriptionArtifact(
      content: content(timings: input.timings),
      language: TranscriptionLanguage(
        confidence: nil,
        detected: input.detectedLanguage,
        requested: input.requestedLanguage
      ),
      metrics: metrics(input),
      provenance: provenance(input),
      providerCapture: providerCapture(input),
      schemaVersion: TranscriptionArtifact.currentSchemaVersion,
      text: input.text,
      warnings: []
    )
  }

  private static func content(timings: [TokenTiming]) -> TranscriptionContent {
    let words = buildWordTimings(from: timings)
    return TranscriptionContent(
      audioEvents: TranscriptionCollection(availability: .unsupported, source: nil, items: []),
      segments: TranscriptionCollection(availability: .unsupported, source: nil, items: []),
      speakerTurns: TranscriptionCollection(availability: .unsupported, source: nil, items: []),
      tokens: TranscriptionCollection(
        availability: .available,
        source: .provider,
        items: timings.map { timing in
          TranscriptionToken(
            endSeconds: timing.endTime,
            kind: nil,
            scores: TranscriptionScores(
              confidence: Double(timing.confidence),
              logProbability: nil,
              probability: nil,
              score: nil,
              speakerConfidence: nil
            ),
            speaker: nil,
            startSeconds: timing.startTime,
            text: timing.token,
            tokenID: timing.tokenId
          )
        }
      ),
      words: TranscriptionCollection(
        availability: .available,
        source: .derived,
        items: words.map { word in
          TranscriptionTimedText(
            endSeconds: word.endTime,
            scores: nil,
            speaker: nil,
            startSeconds: word.startTime,
            text: word.word
          )
        }
      )
    )
  }

  private static func metrics(
    _ input: FluidAudioRealtimeArtifactInput
  ) -> TranscriptionMetrics {
    TranscriptionMetrics(
      audioDurationSeconds: Double(input.receivedSampleCount) / 16_000,
      decoderSeconds: nil,
      encoderSeconds: nil,
      firstResultLatencyMs: input.firstPartialAt.map {
        $0.timeIntervalSince(input.startedAt) * 1_000
      },
      gpuUtilization: nil,
      normalizationLatencyMs: nil,
      peakMemoryMB: nil,
      preprocessorSeconds: nil,
      processingSeconds: nil,
      providerLatencyMs: nil,
      queueDelayMs: nil,
      realtimeSpeedFactor: nil,
      tokensPerSecond: nil,
      usage: TranscriptionUsage(inputTokens: nil, outputTokens: nil, totalTokens: nil),
      wallLatencyMs: input.completedAt.timeIntervalSince(input.startedAt) * 1_000
    )
  }

  private static func provenance(
    _ input: FluidAudioRealtimeArtifactInput
  ) -> TranscriptionProvenance {
    TranscriptionProvenance(
      completedAt: input.completedAt,
      executor: .local,
      libraryName: "FluidAudio",
      libraryVersion: "0.15.5",
      model: input.route.rawValue,
      provider: "nvidia",
      providerRequestID: nil,
      runID: UUID().uuidString,
      startedAt: input.startedAt,
      transport: .realtime,
      upstreamModel: input.route.rawValue
    )
  }

  private static func providerCapture(
    _ input: FluidAudioRealtimeArtifactInput
  ) -> TranscriptionProviderCapture {
    let tokenPayload: [TranscriptionJSONValue] = input.timings.map { timing in
      .object([
        "confidence": .number(Double(timing.confidence)),
        "endTime": .number(timing.endTime),
        "startTime": .number(timing.startTime),
        "token": .string(timing.token),
        "tokenId": .number(Double(timing.tokenId)),
      ])
    }
    return TranscriptionProviderCapture(
      metadata: input.providerMetadata,
      response: TranscriptionProviderResponse(
        mediaType: "application/json",
        payload: [
          "text": .string(input.text),
          "timings": .array(tokenPayload),
        ]
      )
    )
  }
}
