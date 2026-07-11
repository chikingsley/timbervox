import Foundation

struct DictationWorkflowCallbacks: Sendable {
  var onLevel: @Sendable (Float) -> Void
  var onSamples: @Sendable ([Float]) -> Void
  var onLiveTranscript: @Sendable (String) -> Void
  var onRealtimeError: @Sendable (String) -> Void
  var onRecordingError: @Sendable (String) -> Void = { _ in }
}

struct DictationResult: Sendable {
  var rawText: String
  var finalText: String
  var model: String
  var modeID: String
  var modeName: String
  var provider: String?
  var language: String?
  var providerLatencyMs: Double?
  var duration: TimeInterval
  var audioURL: URL
  var deliveryNote: String
  var persistenceWarning: String?
}

enum DictationWorkflowError: LocalizedError {
  case alreadyRecording
  case applicationSupportDirectoryUnavailable
  case missingActivePlan
  case recordingPreserved(URL, TimeInterval, String)

  var errorDescription: String? {
    switch self {
    case .alreadyRecording:
      "A dictation recording is already active."
    case .applicationSupportDirectoryUnavailable:
      "Application Support is unavailable."
    case .missingActivePlan:
      "No dictation mode was active for this recording."
    case .recordingPreserved(let url, _, let reason):
      "\(reason) The recording is safe at \(url.lastPathComponent)."
    }
  }

  var preservedRecording: (url: URL, duration: TimeInterval)? {
    guard case .recordingPreserved(let url, let duration, _) = self else { return nil }
    return (url, duration)
  }
}

@MainActor
final class DictationWorkflow {
  private let logger = TimberVoxLog.dictation
  private let recorder: DictationAudioRecorder
  private let cloud: CloudClients
  private let pasteService: PasteService
  private let transcriptStore: TranscriptStore
  private let modeStore: ModeStore
  private let catalogStore: TranscriptionModelCatalogStore
  private let realtimeSession: RealtimeTranscriptionSession
  private let localBatchTranscription: LocalBatchTranscriptionClient
  private let localRealtimeSession: LocalRealtimeTranscriptionSession
  private let contextCaptureService: DictationContextCaptureService
  private let playbackPolicy = PlaybackPolicyCoordinator()

  private var activePlan: DictationExecutionPlan?
  private var activeContext: DictationContext?
  private var activeContextSession: DictationContextCaptureSession?

  init(
    recorder: DictationAudioRecorder = DictationAudioRecorder(),
    cloud: CloudClients = .production,
    pasteService: PasteService = PasteService(),
    transcriptStore: TranscriptStore = .shared,
    modeStore: ModeStore = .shared,
    catalogStore: TranscriptionModelCatalogStore = .shared,
    localBatchTranscription: LocalBatchTranscriptionClient = .shared,
    localRealtimeSession: LocalRealtimeTranscriptionSession = .shared
  ) {
    self.recorder = recorder
    self.cloud = cloud
    self.pasteService = pasteService
    self.transcriptStore = transcriptStore
    self.modeStore = modeStore
    self.catalogStore = catalogStore
    self.localBatchTranscription = localBatchTranscription
    self.localRealtimeSession = localRealtimeSession
    contextCaptureService = DictationContextCaptureService()
    realtimeSession = RealtimeTranscriptionSession {
      cloud.makeRealtimeTranscriptionClient()
    }
  }

  func start(callbacks: DictationWorkflowCallbacks) async throws -> Date {
    guard activePlan == nil else { throw DictationWorkflowError.alreadyRecording }
    let plan = try await executionPlan()
    let startedAt = Date.now
    let contextSession = await contextCaptureService.startSession(
      mode: plan.mode,
      startedAt: startedAt
    )

    do {
      try await startRealtimeIfNeeded(plan: plan, callbacks: callbacks)
      let sampleHandler = makeSampleHandler(plan: plan, callbacks: callbacks)
      try await recorder.start(
        writingTo: Self.newRecordingURL(),
        includesSystemAudio: plan.mode.includesSystemAudio,
        onLevel: callbacks.onLevel,
        onSamples: sampleHandler
      ) { error in
        callbacks.onRecordingError(error.localizedDescription)
      }
      playbackPolicy.apply(plan.mode.playbackPolicy)
      activePlan = plan
      activeContextSession = contextSession
      activeContext = contextSession?.currentContext
      return startedAt
    } catch {
      contextSession?.cancel()
      await cancelRealtimeSessions()
      throw error
    }
  }

  func stop() async throws -> DictationResult? {
    guard let plan = activePlan else { throw DictationWorkflowError.missingActivePlan }
    do {
      if let activeContextSession {
        activeContext = await activeContextSession.finish().context
      }
      let recording = try await recorder.finish()
      await playbackPolicy.restore()
      guard let recording else {
        await cancelRealtimeSessions()
        clearActiveSession()
        return nil
      }
      defer { clearActiveSession() }

      let transcription: WorkflowTranscription
      do {
        transcription = try await transcribe(recordingURL: recording.url, plan: plan)
      } catch let error as TimberVoxCloudError {
        if case .uploadFailed = error {
          throw DictationWorkflowError.recordingPreserved(
            recording.url,
            recording.duration,
            error.localizedDescription
          )
        }
        throw error
      }
      let finalTranscript = try await transform(transcription.rawText, mode: plan.mode)
      let persistenceWarning = persist(
        recording: recording,
        plan: plan,
        transcription: transcription,
        finalTranscript: finalTranscript
      )
      let deliveryNote = await deliver(finalTranscript)
      return DictationResult(
        rawText: transcription.rawText,
        finalText: finalTranscript,
        model: plan.route.model,
        modeID: plan.mode.id,
        modeName: plan.mode.name,
        provider: transcription.provider,
        language: transcription.language,
        providerLatencyMs: transcription.providerLatencyMs,
        duration: recording.duration,
        audioURL: recording.url,
        deliveryNote: deliveryNote,
        persistenceWarning: persistenceWarning
      )
    } catch {
      await cancelRealtimeSessions()
      await playbackPolicy.restore()
      clearActiveSession()
      throw error
    }
  }

  func cancel() async {
    await cancelRealtimeSessions()
    activeContextSession?.cancel()
    await recorder.cancel()
    await playbackPolicy.restore()
    clearActiveSession()
  }

  private func executionPlan() async throws -> DictationExecutionPlan {
    await catalogStore.refreshIfNeeded()
    guard !catalogStore.models.isEmpty else {
      let reason = catalogStore.lastError ?? "The transcription catalog did not contain any models."
      throw TimberVoxCloudError.configuration("Transcription model catalog unavailable: \(reason)")
    }
    let currentMode = modeStore.activeMode
    let normalizedMode = catalogStore.normalized(currentMode)
    if normalizedMode != currentMode {
      modeStore.updateActive { $0 = normalizedMode }
    }
    return try ModeCatalogResolver.executionPlan(
      for: normalizedMode,
      catalog: catalogStore.models
    )
  }

  private func startRealtimeIfNeeded(
    plan: DictationExecutionPlan,
    callbacks: DictationWorkflowCallbacks
  ) async throws {
    await cancelRealtimeSessions()
    guard plan.transport == .realtime else { return }
    switch plan.route.executor {
    case .cloud:
      try await realtimeSession.start(
        model: plan.route.model,
        language: plan.mode.languageCode,
        onTranscript: callbacks.onLiveTranscript,
        onError: callbacks.onRealtimeError
      )
    case .local(let route):
      await localBatchTranscription.releaseLoadedModel()
      try await localRealtimeSession.start(
        route: route,
        language: plan.mode.languageCode,
        onTranscript: callbacks.onLiveTranscript
      )
    }
  }

  private func makeSampleHandler(
    plan: DictationExecutionPlan,
    callbacks: DictationWorkflowCallbacks
  ) -> @Sendable ([Float]) -> Void {
    { [weak self] samples in
      callbacks.onSamples(samples)
      Task { @MainActor in
        await self?.sendRealtimePCM(samples, plan: plan, onError: callbacks.onRealtimeError)
      }
    }
  }

  private func transcribe(
    recordingURL: URL,
    plan: DictationExecutionPlan
  ) async throws -> WorkflowTranscription {
    if plan.transport == .realtime {
      let rawText: String
      switch plan.route.executor {
      case .cloud:
        rawText = try await realtimeSession.finish()
      case .local:
        rawText = try await localRealtimeSession.finish()
      }
      return WorkflowTranscription(
        rawText: rawText,
        provider: plan.route.provider,
        providerLatencyMs: nil,
        language: plan.mode.languageCode
      )
    }

    switch plan.route.executor {
    case .cloud:
      let outcome = try await cloud.batchTranscription.transcribe(
        wavAt: recordingURL,
        model: plan.route.model,
        language: plan.mode.languageCode,
        diarize: plan.mode.diarizationEnabled
      )
      return WorkflowTranscription(
        rawText: outcome.rawText,
        provider: outcome.provider,
        providerLatencyMs: outcome.providerLatencyMs,
        language: outcome.language ?? plan.mode.languageCode
      )
    case .local(let route):
      await localRealtimeSession.releaseLoadedModel()
      let start = Date.now
      let rawText = try await localBatchTranscription.transcribe(
        wavAt: recordingURL,
        route: route
      )
      let latency = Date.now.timeIntervalSince(start) * 1_000
      return WorkflowTranscription(
        rawText: rawText,
        provider: plan.route.provider,
        providerLatencyMs: latency,
        language: plan.mode.languageCode
      )
    }
  }

  private func transform(_ rawTranscript: String, mode: DictationMode) async throws -> String {
    let context =
      activeContext
      ?? (mode.usesTextTransform ? SystemDictationContextProvider.capture(for: mode) : nil)
    guard let request = mode.textTransformRequest(rawTranscript: rawTranscript, context: context) else {
      return rawTranscript
    }
    let outcome = try await cloud.textTransform.transform(request: request)
    let text = outcome.text.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? rawTranscript : text
  }

  private func persist(
    recording: (url: URL, duration: TimeInterval),
    plan: DictationExecutionPlan,
    transcription: WorkflowTranscription,
    finalTranscript: String
  ) -> String? {
    do {
      _ = try transcriptStore.save(
        text: finalTranscript,
        rawText: plan.mode.usesTextTransform ? transcription.rawText : nil,
        duration: recording.duration,
        model: plan.route.model,
        modeID: plan.mode.id,
        modeName: plan.mode.name,
        audioPath: recording.url.path,
        provider: transcription.provider,
        providerLatencyMs: transcription.providerLatencyMs,
        language: transcription.language,
        transformPreset: plan.mode.usesTextTransform ? plan.mode.textTransformPreset.rawValue : nil,
        transformModel: plan.mode.usesTextTransform ? plan.mode.textTransformModelID : nil
      )
      return nil
    } catch {
      logger.error("Transcript persistence failed: \(error.localizedDescription)")
      return "Transcript history was not saved: \(error.localizedDescription)"
    }
  }

  private func deliver(_ transcript: String) async -> String {
    if await pasteService.paste(transcript) {
      return "Pasted where you were typing"
    }
    pasteService.copy(transcript)
    return "On your clipboard — press ⌘V (auto-paste needs Accessibility)"
  }

  private func clearActiveSession() {
    activeContextSession?.cleanupAttachments()
    activePlan = nil
    activeContext = nil
    activeContextSession = nil
  }

  private static func newRecordingURL() throws -> URL {
    guard
      let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else {
      throw DictationWorkflowError.applicationSupportDirectoryUnavailable
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let name = "Recording-\(formatter.string(from: .now)).wav"
    return applicationSupport.appendingPathComponent("TimberVox/Recordings/\(name)")
  }
}

private extension DictationWorkflow {
  func sendRealtimePCM(
    _ samples: [Float],
    plan: DictationExecutionPlan,
    onError: @escaping @Sendable (String) -> Void
  ) async {
    guard plan.transport == .realtime else { return }
    switch plan.route.executor {
    case .cloud:
      await realtimeSession.sendPCM(samples)
    case .local:
      do {
        try await localRealtimeSession.sendPCM(samples)
      } catch {
        onError(error.localizedDescription)
      }
    }
  }

  func cancelRealtimeSessions() async {
    await realtimeSession.cancel()
    await localRealtimeSession.cancel()
  }
}

private struct WorkflowTranscription {
  var rawText: String
  var provider: String?
  var providerLatencyMs: Double?
  var language: String?
}
