import AVFoundation
@preconcurrency import FluidAudio
import Foundation

private struct SendableAsrManager: @unchecked Sendable {
  let value: AsrManager
}

actor LocalBatchTranscriptionClient {
  static let shared = LocalBatchTranscriptionClient()

  private var manager: SendableAsrManager?
  private var loadedRoute: LocalTranscriptionRouteID?
  private var unloadTask: Task<Void, Never>?

  func transcribe(wavAt url: URL, route: LocalTranscriptionRouteID) async throws -> String {
    cancelScheduledUnload()
    defer { scheduleUnload() }
    try await ensureLoaded(route) { _ in }
    guard let manager else {
      throw LocalTranscriptionError.modelUnavailable(route.rawValue)
    }

    let prepared = try LocalParakeetClipPreparer.ensureMinimumDuration(url: url)
    defer { prepared.cleanup() }
    var decoderState = TdtDecoderState.make(decoderLayers: await manager.value.decoderLayerCount)
    let result = try await manager.value.transcribe(prepared.url, decoderState: &decoderState)
    let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw LocalTranscriptionError.emptyResult }
    return text
  }

  func isDownloaded(route: LocalTranscriptionRouteID) -> Bool {
    guard let version = modelVersion(for: route) else { return false }
    let directory = AsrModels.defaultCacheDirectory(for: version)
    return AsrModels.modelsExist(at: directory, version: version)
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
      throw LocalTranscriptionError.unsupportedRoute(route.rawValue)
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
      throw LocalTranscriptionError.unsupportedRoute(route.rawValue)
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
      let duration = LocalModelRetentionPreference.idleDuration
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
}

enum LocalTranscriptionError: LocalizedError {
  case bufferAllocationFailed
  case emptyResult
  case languageRequired
  case modelUnavailable(String)
  case unsupportedRoute(String)

  var errorDescription: String? {
    switch self {
    case .bufferAllocationFailed:
      "Unable to allocate a local transcription audio buffer."
    case .emptyResult:
      "The local model returned an empty transcript."
    case .languageRequired:
      "Choose a language before using this local realtime model."
    case .modelUnavailable(let model):
      "The local model \(model) is unavailable."
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
      throw LocalTranscriptionError.bufferAllocationFailed
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
      throw LocalTranscriptionError.bufferAllocationFailed
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
      throw LocalTranscriptionError.bufferAllocationFailed
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
