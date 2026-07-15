import Foundation

enum DictationTextOutput {
  case processed(text: String, capture: TextTransformationCapture)
  case transcribed(String)

  var text: String {
    switch self {
    case .processed(let text, _): text
    case .transcribed(let text): text
    }
  }

  var transformation: TextTransformationCapture? {
    guard case .processed(_, let capture) = self else { return nil }
    return capture
  }
}

private struct DictationTextProcessingFailure: LocalizedError {
  var capture: TextTransformationCapture
  var failure: DictationFailure

  var errorDescription: String? { failure.message }
}

extension DictationWorkflow {
  func transcriptionArtifact(
    for recording: (url: URL, duration: TimeInterval),
    plan: DictationExecutionPlan
  ) async throws -> TranscriptionArtifact {
    let artifact: TranscriptionArtifact
    do {
      artifact = try await transcribe(recordingURL: recording.url, plan: plan)
    } catch {
      let failure = DictationFailure.transcription(error)
      let warning = persistFailure(
        recording: recording,
        plan: plan,
        artifact: (error as? TranscriptionRuntimeError)?.artifact,
        failure: failure
      )
      throw DictationWorkflowError.failedAttempt(
        failure: failure,
        recordingURL: recording.url,
        duration: recording.duration,
        persistenceWarning: warning
      )
    }
    guard !artifact.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      let failure = DictationFailure.transcription(TranscriptionRuntimeError.emptyResult)
      let warning = persistFailure(
        recording: recording,
        plan: plan,
        artifact: artifact,
        failure: failure
      )
      throw DictationWorkflowError.failedAttempt(
        failure: failure,
        recordingURL: recording.url,
        duration: recording.duration,
        persistenceWarning: warning
      )
    }
    return artifact
  }

  func textOutput(
    for artifact: TranscriptionArtifact,
    recording: (url: URL, duration: TimeInterval),
    plan: DictationExecutionPlan
  ) async throws -> DictationTextOutput {
    do {
      return try await transform(artifact.displayText, mode: plan.mode)
    } catch {
      let processingFailure = error as? DictationTextProcessingFailure
      let failure = processingFailure?.failure ?? DictationFailure.textProcessing(error)
      let warning = persistFailure(
        recording: recording,
        plan: plan,
        artifact: artifact,
        failure: failure,
        transformation: processingFailure?.capture
      )
      throw DictationWorkflowError.failedAttempt(
        failure: failure,
        recordingURL: recording.url,
        duration: recording.duration,
        persistenceWarning: warning
      )
    }
  }

  func result(
    recording: (url: URL, duration: TimeInterval),
    plan: DictationExecutionPlan,
    artifact: TranscriptionArtifact,
    textOutput: DictationTextOutput,
    persistenceWarning: String?
  ) async -> DictationResult {
    let deliveryNote = await deliver(textOutput.text)
    return DictationResult(
      rawText: artifact.displayText,
      finalText: textOutput.text,
      model: plan.route.model,
      modeID: plan.mode.id,
      modeName: plan.mode.name,
      provider: artifact.provenance.provider,
      language: artifact.language.detected ?? artifact.language.requested,
      wallLatencyMs: artifact.metrics.wallLatencyMs,
      duration: recording.duration,
      audioURL: recording.url,
      deliveryNote: deliveryNote,
      persistenceWarning: persistenceWarning
    )
  }

  private func transform(
    _ rawTranscript: String,
    mode: DictationMode
  ) async throws -> DictationTextOutput {
    let context =
      activeContext
      ?? (mode.usesTextTransform ? SystemDictationContextProvider.capture(for: mode) : nil)
    guard let request = mode.textTransformRequest(rawTranscript: rawTranscript, context: context) else {
      return .transcribed(rawTranscript)
    }
    let startedAt = Date.now
    let stream = try await textStream(request: request, startedAt: startedAt)
    let completedAt = Date.now
    let text = stream.outcome.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
      throw emptyTextFailure(
        stream: stream,
        request: request,
        startedAt: startedAt,
        completedAt: completedAt
      )
    }
    return .processed(
      text: text,
      capture: transformationCapture(
        stream: stream,
        request: request,
        startedAt: startedAt,
        completedAt: completedAt
      )
    )
  }

  private func textStream(
    request: TextTransformRequest,
    startedAt: Date
  ) async throws -> TextTransformStreamResult {
    do {
      let onProcessingText = activeCallbacks?.onProcessingText
      return try await textTransform.streamTransform(request: request) { text in
        onProcessingText?(text)
      }
    } catch {
      let completedAt = Date.now
      throw DictationTextProcessingFailure(
        capture: TextTransformationCapture(
          completedAt: completedAt,
          failure: TextTransformationFailure(error: error),
          outcome: nil,
          request: request,
          schemaVersion: TextTransformationCapture.currentSchemaVersion,
          startedAt: startedAt,
          streamEvents: (error as? TextTransformStreamError)?.events ?? [],
          wallLatencyMs: completedAt.timeIntervalSince(startedAt) * 1_000
        ),
        failure: DictationFailure.textProcessing(error)
      )
    }
  }

  private func emptyTextFailure(
    stream: TextTransformStreamResult,
    request: TextTransformRequest,
    startedAt: Date,
    completedAt: Date
  ) -> DictationTextProcessingFailure {
    let error = DictationWorkflowError.emptyTransformation
    return DictationTextProcessingFailure(
      capture: TextTransformationCapture(
        completedAt: completedAt,
        failure: TextTransformationFailure(error: error),
        outcome: stream.outcome,
        request: request,
        schemaVersion: TextTransformationCapture.currentSchemaVersion,
        startedAt: startedAt,
        streamEvents: stream.events,
        wallLatencyMs: completedAt.timeIntervalSince(startedAt) * 1_000
      ),
      failure: DictationFailure.textProcessing(error)
    )
  }

  private func transformationCapture(
    stream: TextTransformStreamResult,
    request: TextTransformRequest,
    startedAt: Date,
    completedAt: Date
  ) -> TextTransformationCapture {
    TextTransformationCapture(
      completedAt: completedAt,
      outcome: stream.outcome,
      request: request,
      schemaVersion: TextTransformationCapture.currentSchemaVersion,
      startedAt: startedAt,
      streamEvents: stream.events,
      wallLatencyMs: completedAt.timeIntervalSince(startedAt) * 1_000
    )
  }

  func persist(
    recording: (url: URL, duration: TimeInterval),
    plan: DictationExecutionPlan,
    artifact: TranscriptionArtifact,
    textOutput: DictationTextOutput
  ) -> String? {
    do {
      _ = try transcriptStore.save(
        text: textOutput.text,
        rawText: plan.mode.usesTextTransform ? artifact.displayText : nil,
        artifact: artifact,
        duration: recording.duration,
        modeID: plan.mode.id,
        modeName: plan.mode.name,
        audioPath: recording.url.path,
        transformPreset: plan.mode.usesTextTransform ? plan.mode.textTransformPreset.rawValue : nil,
        transformModel: plan.mode.usesTextTransform ? plan.mode.textTransformModelID : nil,
        transformation: textOutput.transformation,
        contextSnapshot: activeContextSnapshot,
        sourceApplicationName: activeSourceApplication?.name,
        sourceApplicationBundleIdentifier: activeSourceApplication?.bundleIdentifier
      )
      activeContextWasPersisted = true
      return nil
    } catch {
      logger.error("Transcript persistence failed: \(error.localizedDescription)")
      return "Transcript history was not saved: \(error.localizedDescription)"
    }
  }

  private func persistFailure(
    recording: (url: URL, duration: TimeInterval),
    plan: DictationExecutionPlan,
    artifact: TranscriptionArtifact?,
    failure: DictationFailure,
    transformation: TextTransformationCapture? = nil
  ) -> String? {
    do {
      _ = try transcriptStore.saveFailure(
        TranscriptFailureInput(
          failure: failure,
          artifact: artifact,
          duration: recording.duration,
          model: plan.route.model,
          modeID: plan.mode.id,
          modeName: plan.mode.name,
          audioPath: recording.url.path,
          provider: plan.route.provider,
          language: plan.mode.languageCode,
          transformPreset: transformation == nil ? nil : plan.mode.textTransformPreset.rawValue,
          transformModel: transformation == nil ? nil : plan.mode.textTransformModelID,
          transformation: transformation,
          contextSnapshot: activeContextSnapshot,
          sourceApplicationName: activeSourceApplication?.name,
          sourceApplicationBundleIdentifier: activeSourceApplication?.bundleIdentifier
        )
      )
      activeContextWasPersisted = true
      return nil
    } catch {
      logger.error("Failed dictation persistence failed: \(error.localizedDescription)")
      return "Dictation failure was not saved to History: \(error.localizedDescription)"
    }
  }

  private func deliver(_ transcript: String) async -> String {
    if await textDelivery.paste(transcript) {
      return "Pasted where you were typing"
    }
    textDelivery.copy(transcript)
    return "On your clipboard — press ⌘V (auto-paste needs Accessibility)"
  }
}
