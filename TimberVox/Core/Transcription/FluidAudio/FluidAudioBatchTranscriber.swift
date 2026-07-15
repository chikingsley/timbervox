import AVFoundation
@preconcurrency import FluidAudio
import Foundation

private struct SendableAsrManager: @unchecked Sendable {
  let value: AsrManager
}

actor FluidAudioBatchTranscriber {
  static let shared = FluidAudioBatchTranscriber()

  private var manager: SendableAsrManager?
  private var loadedRoute: LocalTranscriptionRouteID?
  private var unloadTask: Task<Void, Never>?

  func transcribe(
    wavAt url: URL,
    route: LocalTranscriptionRouteID,
    requestedLanguage: String? = nil
  ) async throws -> TranscriptionArtifact {
    let startedAt = Date.now
    cancelScheduledUnload()
    defer { scheduleUnload() }
    try await ensureLoaded(route) { _ in }
    guard let manager else {
      throw FluidAudioTranscriptionError.modelUnavailable(route.rawValue)
    }

    let audioDurationSeconds = try Self.audioDurationSeconds(at: url)
    let prepared = try LocalParakeetClipPreparer.ensureMinimumDuration(url: url)
    defer { prepared.cleanup() }
    var decoderState = TdtDecoderState.make(decoderLayers: await manager.value.decoderLayerCount)
    let result = try await manager.value.transcribe(prepared.url, decoderState: &decoderState)
    return try Self.artifact(
      result: result,
      route: route,
      requestedLanguage: requestedLanguage,
      audioDurationSeconds: audioDurationSeconds,
      startedAt: startedAt,
      completedAt: .now
    )
  }

  func isDownloaded(route: LocalTranscriptionRouteID) -> Bool {
    guard let version = modelVersion(for: route) else { return false }
    let directory = AsrModels.defaultCacheDirectory(for: version)
    return AsrModels.modelsExist(at: directory, version: version)
  }

  func installedBytes(route: LocalTranscriptionRouteID) -> Int64 {
    guard let version = modelVersion(for: route) else { return 0 }
    return FluidAudioModelStorage.allocatedBytes(
      at: AsrModels.defaultCacheDirectory(for: version)
    )
  }

  func prepare(
    route: LocalTranscriptionRouteID,
    progress: @Sendable @escaping (Double) -> Void = { _ in }
  ) async throws {
    cancelScheduledUnload()
    try await ensureLoaded(route, progress: progress)
    scheduleUnload()
  }

  func releaseLoadedModel() {
    cancelScheduledUnload()
    manager = nil
    loadedRoute = nil
  }

  func retentionPreferenceDidChange() {
    scheduleUnload()
  }

  func delete(route: LocalTranscriptionRouteID) throws {
    guard let version = modelVersion(for: route) else {
      throw FluidAudioTranscriptionError.unsupportedRoute(route.rawValue)
    }
    let directory = AsrModels.defaultCacheDirectory(for: version)
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
    if loadedRoute == route {
      releaseLoadedModel()
    }
  }

  private func ensureLoaded(
    _ route: LocalTranscriptionRouteID,
    progress: @Sendable @escaping (Double) -> Void
  ) async throws {
    guard let version = modelVersion(for: route) else {
      throw FluidAudioTranscriptionError.unsupportedRoute(route.rawValue)
    }
    guard loadedRoute != route || manager == nil else { return }

    // Do not retain the previous Core ML graph while the replacement route is
    // compiled and loaded. That peak is large enough to terminate the process
    // on a 16 GB Apple Silicon Mac.
    manager = nil
    loadedRoute = nil

    let models = try await AsrModels.downloadAndLoad(version: version) {
      progress($0.fractionCompleted)
    }
    let manager = AsrManager(config: .init())
    try await manager.loadModels(models)
    self.manager = SendableAsrManager(value: manager)
    loadedRoute = route
  }

  private func cancelScheduledUnload() {
    unloadTask?.cancel()
    unloadTask = nil
  }

  private func scheduleUnload() {
    cancelScheduledUnload()
    guard let route = loadedRoute,
      let duration = FluidAudioModelRetentionPreference.idleDuration
    else { return }
    unloadTask = Task { [weak self] in
      do {
        try await Task.sleep(for: duration)
      } catch {
        return
      }
      await self?.releaseIfLoaded(route)
    }
  }

  private func releaseIfLoaded(_ route: LocalTranscriptionRouteID) {
    guard loadedRoute == route else { return }
    releaseLoadedModel()
  }

  private func modelVersion(for route: LocalTranscriptionRouteID) -> AsrModelVersion? {
    switch route {
    case .parakeetTdtCtc110M: .tdtCtc110m
    case .parakeetTdtV3: .v3
    case .nemotronEnglish560, .nemotronEnglish1120, .nemotronMultilingual1120: nil
    }
  }

  private static func artifact(
    result: ASRResult,
    route: LocalTranscriptionRouteID,
    requestedLanguage: String?,
    audioDurationSeconds: TimeInterval,
    startedAt: Date,
    completedAt: Date
  ) throws -> TranscriptionArtifact {
    let hasTokenTimings = result.tokenTimings != nil
    let tokenTimings = result.tokenTimings ?? []
    let responseData = try JSONEncoder().encode(result)
    let response = try JSONDecoder().decode(
      [String: TranscriptionJSONValue].self,
      from: responseData
    )

    return TranscriptionArtifact(
      content: content(tokenTimings: tokenTimings, hasProviderTimings: hasTokenTimings),
      language: TranscriptionLanguage(
        confidence: nil,
        detected: nil,
        requested: requestedLanguage
      ),
      metrics: metrics(
        result: result,
        tokenCount: hasTokenTimings ? tokenTimings.count : nil,
        audioDurationSeconds: audioDurationSeconds,
        startedAt: startedAt,
        completedAt: completedAt
      ),
      provenance: TranscriptionProvenance(
        completedAt: completedAt,
        executor: .local,
        libraryName: "FluidAudio",
        libraryVersion: "0.15.5",
        model: route.rawValue,
        provider: "nvidia",
        providerRequestID: nil,
        runID: UUID().uuidString,
        startedAt: startedAt,
        transport: .batch,
        upstreamModel: route.rawValue
      ),
      providerCapture: TranscriptionProviderCapture(
        metadata: [:],
        response: TranscriptionProviderResponse(
          mediaType: "application/json",
          payload: response
        )
      ),
      schemaVersion: TranscriptionArtifact.currentSchemaVersion,
      text: result.text,
      warnings: []
    )
  }

  private static func content(
    tokenTimings: [TokenTiming],
    hasProviderTimings: Bool
  ) -> TranscriptionContent {
    let availability: TranscriptionDataAvailability =
      hasProviderTimings ? .available : .providerOmitted
    let source: TranscriptionDataSource? = hasProviderTimings ? .provider : nil
    let wordTimings = buildWordTimings(from: tokenTimings)
    return TranscriptionContent(
      audioEvents: TranscriptionCollection(availability: .unsupported, source: nil, items: []),
      segments: TranscriptionCollection(availability: .unsupported, source: nil, items: []),
      speakerTurns: TranscriptionCollection(availability: .unsupported, source: nil, items: []),
      tokens: TranscriptionCollection(
        availability: availability,
        source: source,
        items: tokenTimings.map { timing in
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
        availability: availability,
        source: source == nil ? nil : .derived,
        items: wordTimings.map { timing in
          TranscriptionTimedText(
            endSeconds: timing.endTime,
            scores: nil,
            speaker: nil,
            startSeconds: timing.startTime,
            text: timing.word
          )
        }
      )
    )
  }

  private static func metrics(
    result: ASRResult,
    tokenCount: Int?,
    audioDurationSeconds: TimeInterval,
    startedAt: Date,
    completedAt: Date
  ) -> TranscriptionMetrics {
    let performance = result.performanceMetrics
    let processingSeconds = result.processingTime
    return TranscriptionMetrics(
      audioDurationSeconds: audioDurationSeconds,
      decoderSeconds: performance?.decoderTime,
      encoderSeconds: performance?.encoderTime,
      firstResultLatencyMs: nil,
      gpuUtilization: performance?.gpuUtilization.map(Double.init),
      normalizationLatencyMs: nil,
      peakMemoryMB: performance.map { Double($0.peakMemoryMB) },
      preprocessorSeconds: performance?.preprocessorTime,
      processingSeconds: processingSeconds,
      providerLatencyMs: nil,
      queueDelayMs: nil,
      realtimeSpeedFactor: processingSeconds > 0 && audioDurationSeconds > 0
        ? audioDurationSeconds / processingSeconds
        : nil,
      tokensPerSecond: tokenCount.map {
        processingSeconds > 0 ? Double($0) / processingSeconds : 0
      },
      usage: TranscriptionUsage(inputTokens: nil, outputTokens: nil, totalTokens: nil),
      wallLatencyMs: completedAt.timeIntervalSince(startedAt) * 1_000
    )
  }

  private static func audioDurationSeconds(at url: URL) throws -> TimeInterval {
    let file = try AVAudioFile(forReading: url)
    return Double(file.length) / file.processingFormat.sampleRate
  }
}

enum FluidAudioTranscriptionError: LocalizedError {
  case bufferAllocationFailed
  case languageRequired
  case modelUnavailable(String)
  case realtimeNotActive
  case unsupportedRoute(String)

  var errorDescription: String? {
    switch self {
    case .bufferAllocationFailed:
      "Unable to allocate a local transcription audio buffer."
    case .languageRequired:
      "Choose a language before using this local realtime model."
    case .modelUnavailable(let model):
      "The local model \(model) is unavailable."
    case .realtimeNotActive:
      "Local realtime transcription was not active."
    case .unsupportedRoute(let route):
      "Unsupported local transcription route: \(route)."
    }
  }
}

private struct LocalParakeetClipPreparation {
  var url: URL
  var cleanupURL: URL?

  func cleanup() {
    guard let cleanupURL else { return }
    try? FileManager.default.removeItem(at: cleanupURL)
  }
}

private enum LocalParakeetClipPreparer {
  static let minimumDuration: TimeInterval = 1.5

  static func ensureMinimumDuration(url: URL) throws -> LocalParakeetClipPreparation {
    let audioFile = try AVAudioFile(forReading: url)
    let format = audioFile.processingFormat
    let duration = Double(audioFile.length) / format.sampleRate
    guard duration < minimumDuration else {
      return LocalParakeetClipPreparation(url: url, cleanupURL: nil)
    }
    guard format.commonFormat == .pcmFormatFloat32 else {
      throw FluidAudioTranscriptionError.bufferAllocationFailed
    }

    let minimumFrames = AVAudioFrameCount((minimumDuration * format.sampleRate).rounded(.up))
    let existingFrames = max(AVAudioFramePosition(0), audioFile.length)
    let capacity = max(
      AVAudioFrameCount(min(existingFrames, AVAudioFramePosition(AVAudioFrameCount.max))),
      1
    )
    guard
      let source = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity),
      let padded = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: minimumFrames)
    else {
      throw FluidAudioTranscriptionError.bufferAllocationFailed
    }

    try audioFile.read(into: source)
    try copyAndPad(source: source, destination: padded, frameCount: minimumFrames)
    let paddedURL = url.deletingPathExtension().appendingPathExtension("local-padded.wav")
    try? FileManager.default.removeItem(at: paddedURL)
    let output = try AVAudioFile(forWriting: paddedURL, settings: audioFile.fileFormat.settings)
    try output.write(from: padded)
    return LocalParakeetClipPreparation(url: paddedURL, cleanupURL: paddedURL)
  }

  private static func copyAndPad(
    source: AVAudioPCMBuffer,
    destination: AVAudioPCMBuffer,
    frameCount: AVAudioFrameCount
  ) throws {
    guard let sourceChannels = source.floatChannelData,
      let destinationChannels = destination.floatChannelData
    else {
      throw FluidAudioTranscriptionError.bufferAllocationFailed
    }
    let copiedFrames = min(source.frameLength, frameCount)
    for channel in 0..<Int(source.format.channelCount) {
      destinationChannels[channel].update(from: sourceChannels[channel], count: Int(copiedFrames))
      destinationChannels[channel].advanced(by: Int(copiedFrames)).initialize(
        repeating: 0,
        count: Int(frameCount - copiedFrames)
      )
    }
    destination.frameLength = frameCount
  }
}
