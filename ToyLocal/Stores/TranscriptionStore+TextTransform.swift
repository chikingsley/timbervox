import Foundation
import ToyLocalCore

private let textTransformLogger = ToyLocalLog.transcription

struct TextTransformApplicationResult {
  let text: String
  let state: TextTransformRunState
}

extension TranscriptionStore {
  func applyTextTransformIfNeeded(
    to transcript: String,
    settings toyLocalSettings: ToyLocalSettings,
    contextSnapshot: DictationContextSnapshot?
  ) async throws -> TextTransformApplicationResult {
    guard toyLocalSettings.textTransformMode.usesTextTransform else {
      return TextTransformApplicationResult(text: transcript, state: .skipped(reason: "Text transform mode is disabled."))
    }
    guard let transformRequest = textTransformRequest(for: toyLocalSettings, contextSnapshot: contextSnapshot) else {
      return TextTransformApplicationResult(text: transcript, state: .skipped(reason: "No text transform request could be built."))
    }

    textTransformState = .running(
      mode: toyLocalSettings.textTransformMode,
      request: transformRequest,
      input: transcript
    )

    let completion = try await transcriptionWorkflow.complete(
      transcript: transcript,
      transformRequest: transformRequest
    )
    guard let completion else {
      return TextTransformApplicationResult(
        text: transcript,
        state: .emptyResult(
          mode: toyLocalSettings.textTransformMode,
          request: transformRequest,
          completion: nil,
          input: transcript
        )
      )
    }

    guard !completion.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return TextTransformApplicationResult(
        text: transcript,
        state: .emptyResult(
          mode: toyLocalSettings.textTransformMode,
          request: transformRequest,
          completion: completion,
          input: transcript
        )
      )
    }

    return TextTransformApplicationResult(
      text: completion.text,
      state: .succeeded(
        mode: toyLocalSettings.textTransformMode,
        request: transformRequest,
        completion: completion,
        input: transcript
      )
    )
  }

  func transcriptionWorkflowRequest(
    for toyLocalSettings: ToyLocalSettings,
    contextSnapshot: DictationContextSnapshot?
  ) -> TranscriptionWorkflowRequest {
    let vocabularyTerms = contextSnapshot?.context.vocabulary ?? []
    let vocabulary: TranscriptionVocabularySelection
    if toyLocalSettings.textTransformMode.usesTextTransform, !vocabularyTerms.isEmpty {
      vocabulary = .textTransformContext(terms: vocabularyTerms)
    } else {
      vocabulary = .disabled
    }

    return TranscriptionWorkflowRequest(
      asrModelID: toyLocalSettings.selectedModel,
      language: toyLocalSettings.outputLanguage,
      vocabulary: vocabulary,
      textTransform: textTransformRequest(for: toyLocalSettings, contextSnapshot: contextSnapshot)
    )
  }

  func textTransformRequest(
    for toyLocalSettings: ToyLocalSettings,
    contextSnapshot: DictationContextSnapshot?
  ) -> TranscriptTransformRequest? {
    guard toyLocalSettings.textTransformMode.usesTextTransform,
      let preset = textTransformPreset(for: toyLocalSettings)
    else {
      return nil
    }

    return TranscriptTransformRequest(
      modelID: toyLocalSettings.textTransformModel,
      preset: preset,
      context: contextSnapshot?.context,
      contextOptions: toyLocalSettings.textTransformContextOptions
    )
  }

  func textTransformPreset(for toyLocalSettings: ToyLocalSettings) -> TextTransformPreset? {
    guard let presetID = toyLocalSettings.textTransformMode.presetID else {
      return nil
    }
    if presetID == .customPrompt {
      return .custom(toyLocalSettings.customTextTransformInstructions)
    }
    return TextTransformPreset.builtIn(id: presetID)
  }

  func applyTranscriptModifications(
    _ result: String,
    settings toyLocalSettings: ToyLocalSettings
  ) -> String {
    guard !settings.isRemappingScratchpadFocused else {
      textTransformLogger.info("Scratchpad focused; skipping word modifications")
      return result
    }

    var output = result
    if toyLocalSettings.wordRemovalsEnabled {
      let removedResult = WordRemovalApplier.apply(output, removals: toyLocalSettings.wordRemovals)
      if removedResult != output {
        let enabledRemovalCount = toyLocalSettings.wordRemovals.filter(\.isEnabled).count
        textTransformLogger.info("Applied \(enabledRemovalCount) word removal(s)")
      }
      output = removedResult
    }

    let remappedResult = WordRemappingApplier.apply(output, remappings: toyLocalSettings.wordRemappings)
    if remappedResult != output {
      textTransformLogger.info("Applied \(toyLocalSettings.wordRemappings.count) word remapping(s)")
    }
    return remappedResult
  }
}
