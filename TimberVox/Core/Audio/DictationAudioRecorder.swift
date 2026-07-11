import Foundation

actor DictationAudioRecorder {
  private let microphoneRecorder: MicrophoneRecorder
  private let aggregateAudioRecorder: AggregateAudioRecorder

  private var finalURL: URL?
  private var microphoneURL: URL?
  private var systemAudioURL: URL?
  private var includesSystemAudio = false

  init(
    microphoneRecorder: MicrophoneRecorder = MicrophoneRecorder(),
    aggregateAudioRecorder: AggregateAudioRecorder = AggregateAudioRecorder()
  ) {
    self.microphoneRecorder = microphoneRecorder
    self.aggregateAudioRecorder = aggregateAudioRecorder
  }

  func start(
    writingTo url: URL,
    includesSystemAudio: Bool,
    onLevel: (@Sendable (Float) -> Void)? = nil,
    onSamples: (@Sendable ([Float]) -> Void)? = nil,
    onError: (@Sendable (Error) -> Void)? = nil
  ) async throws {
    self.includesSystemAudio = includesSystemAudio
    finalURL = url

    if includesSystemAudio {
      let microphoneURL = stemURL(for: url, suffix: "microphone")
      let systemAudioURL = stemURL(for: url, suffix: "system")
      self.microphoneURL = microphoneURL
      self.systemAudioURL = systemAudioURL
      do {
        try aggregateAudioRecorder.start(
          writingTo: url,
          microphoneURL: microphoneURL,
          systemURL: systemAudioURL,
          onLevel: onLevel,
          onSamples: onSamples,
          onError: onError
        )
      } catch {
        aggregateAudioRecorder.cancel()
        clearState()
        throw error
      }
    } else {
      microphoneURL = url
      try await microphoneRecorder.start(
        writingTo: url,
        onLevel: onLevel,
        onSamples: onSamples
      )
    }
  }

  func finish() async throws -> (url: URL, duration: TimeInterval)? {
    guard finalURL != nil else { return nil }
    guard includesSystemAudio else {
      defer { clearState() }
      return await microphoneRecorder.finish()
    }

    guard let recording = try aggregateAudioRecorder.finish() else {
      clearState()
      return nil
    }
    defer {
      if let microphoneURL {
        try? FileManager.default.removeItem(at: microphoneURL)
      }
      if let systemAudioURL {
        try? FileManager.default.removeItem(at: systemAudioURL)
      }
      clearState()
    }
    return recording
  }

  func cancel() async {
    await microphoneRecorder.cancel()
    aggregateAudioRecorder.cancel()
    if let finalURL, finalURL != microphoneURL {
      try? FileManager.default.removeItem(at: finalURL)
    }
    clearState()
  }

  private func stemURL(for url: URL, suffix: String) -> URL {
    let base = url.deletingPathExtension().lastPathComponent
    return url.deletingLastPathComponent().appendingPathComponent("\(base)-\(suffix).wav")
  }

  private func clearState() {
    finalURL = nil
    microphoneURL = nil
    systemAudioURL = nil
    includesSystemAudio = false
  }
}
