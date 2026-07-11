@preconcurrency import AVFoundation
@preconcurrency import FluidAudio
import Foundation

actor LocalRealtimeTranscriptionSession {
  static let shared = LocalRealtimeTranscriptionSession()

  private static let modelLanguageCodes = [
    "de": "de",
    "en": "en",
    "es": "es",
    "fr": "fr",
    "it": "it",
    "ja": "ja-JP",
    "pt": "pt",
    "zh": "zh-CN",
  ]

  private var englishManager: StreamingNemotronAsrManager?
  private var multilingualManager: StreamingNemotronMultilingualAsrManager?
  private var multilingualShared: SharedNemotronMultilingualModels?
  private var loadedRoute: LocalTranscriptionRouteID?
  private var loadedVariant: String?
  private var onTranscript: (@Sendable (String) -> Void)?
  private var unloadTask: Task<Void, Never>?

  func start(
    route: LocalTranscriptionRouteID,
    language: String?,
    onTranscript: @escaping @Sendable (String) -> Void
  ) async throws {
    cancelScheduledUnload()
    try await ensureLoaded(route: route, language: language) { _ in }
    self.onTranscript = onTranscript

    if let englishManager {
      await englishManager.reset()
      await englishManager.setPartialCallback(onTranscript)
    } else if let multilingualManager {
      await multilingualManager.reset()
      await multilingualManager.setLanguage(Self.modelLanguageCode(for: language))
      await multilingualManager.setPartialCallback(onTranscript)
    }
  }

  func sendPCM(_ samples: [Float]) async throws {
    guard !samples.isEmpty else { return }
    let buffer = try Self.makeBuffer(samples)
    if let englishManager {
      _ = try await englishManager.process(audioBuffer: buffer)
      return
    }
    if let multilingualManager {
      _ = try await multilingualManager.process(audioBuffer: buffer)
      return
    }
    throw LocalTranscriptionError.modelUnavailable(loadedRoute?.rawValue ?? "realtime")
  }

  func finish() async throws -> String {
    defer {
      onTranscript = nil
      scheduleUnload()
    }
    let result: String
    if let englishManager {
      result = try await englishManager.finish()
    } else if let multilingualManager {
      result = try await multilingualManager.finish()
    } else {
      throw LocalTranscriptionError.modelUnavailable(loadedRoute?.rawValue ?? "realtime")
    }
    let text = result.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw LocalTranscriptionError.emptyResult }
    return text
  }

  func cancel() async {
    await englishManager?.reset()
    await multilingualManager?.reset()
    onTranscript = nil
    scheduleUnload()
  }

  func isDownloaded(route: LocalTranscriptionRouteID, language: String?) -> Bool {
    guard let directory = Self.cacheDirectory(route: route, language: language) else { return false }
    return Self.requiredFiles(route: route).allSatisfy {
      FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
    }
  }

  func prepare(
    route: LocalTranscriptionRouteID,
    language: String?,
    progress: @Sendable @escaping (Double) -> Void = { _ in }
  ) async throws {
    cancelScheduledUnload()
    try await ensureLoaded(route: route, language: language, progress: progress)
    scheduleUnload()
  }

  func releaseLoadedModel() {
    cancelScheduledUnload()
    englishManager = nil
    multilingualManager = nil
    multilingualShared = nil
    loadedRoute = nil
    loadedVariant = nil
    onTranscript = nil
  }

  func retentionPreferenceDidChange() {
    guard onTranscript == nil else { return }
    scheduleUnload()
  }

  func delete(route: LocalTranscriptionRouteID, language: String?) throws {
    guard let directory = Self.cacheDirectory(route: route, language: language) else {
      throw LocalTranscriptionError.unsupportedRoute(route.rawValue)
    }
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
    if loadedRoute == route, loadedVariant == Self.variant(route: route, language: language) {
      releaseLoadedModel()
    }
  }

  private func ensureLoaded(
    route: LocalTranscriptionRouteID,
    language: String?,
    progress: @Sendable @escaping (Double) -> Void
  ) async throws {
    let variant = Self.variant(route: route, language: language)
    if loadedRoute == route, loadedVariant == variant,
      englishManager != nil || multilingualManager != nil
    {
      return
    }

    // A route change can temporarily require several gigabytes of Core ML
    // state. Release the previous route before compiling/loading the next one
    // instead of holding both model graphs at the same time.
    releaseLoadedModel()

    switch route {
    case .nemotronEnglish560, .nemotronEnglish1120:
      let chunk: NemotronChunkSize = route == .nemotronEnglish560 ? .ms560 : .ms1120
      let manager = StreamingNemotronAsrManager(requestedChunkSize: chunk)
      try await manager.loadModels { progress($0.fractionCompleted) }
      englishManager = manager
      multilingualManager = nil
      multilingualShared = nil
    case .nemotronMultilingual1120:
      guard let language else { throw LocalTranscriptionError.languageRequired }
      let shared = try await StreamingNemotronMultilingualAsrManager.downloadAndPreloadShared(
        languageCode: language,
        chunkMs: 1120
      ) { progress($0.fractionCompleted) }
      let manager = StreamingNemotronMultilingualAsrManager()
      try await manager.loadFromShared(shared)
      multilingualShared = shared
      multilingualManager = manager
      englishManager = nil
    case .parakeetTdtCtc110M, .parakeetTdtV3:
      throw LocalTranscriptionError.unsupportedRoute(route.rawValue)
    }

    loadedRoute = route
    loadedVariant = variant
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
    let variant = loadedVariant
    unloadTask = Task { [weak self] in
      do {
        try await Task.sleep(for: duration)
      } catch {
        return
      }
      await self?.releaseIfLoaded(route: route, variant: variant)
    }
  }

  private func releaseIfLoaded(
    route: LocalTranscriptionRouteID,
    variant: String?
  ) {
    guard loadedRoute == route, loadedVariant == variant else { return }
    releaseLoadedModel()
  }

  private static func variant(
    route: LocalTranscriptionRouteID,
    language: String?
  ) -> String? {
    guard route == .nemotronMultilingual1120, let language else { return nil }
    return StreamingNemotronMultilingualAsrManager.languageDirectory(for: language)
  }

  private static func modelLanguageCode(for language: String?) -> String? {
    guard let language else { return nil }
    return modelLanguageCodes[language] ?? language
  }

  private static func cacheDirectory(
    route: LocalTranscriptionRouteID,
    language: String?
  ) -> URL? {
    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FluidAudio/Models", isDirectory: true)
    switch route {
    case .nemotronEnglish560:
      return root.appendingPathComponent("nemotron-streaming/560ms", isDirectory: true)
    case .nemotronEnglish1120:
      return root.appendingPathComponent("nemotron-streaming/1120ms", isDirectory: true)
    case .nemotronMultilingual1120:
      guard let language else { return nil }
      let latinLanguages = ["de", "en", "es", "fr", "it", "pt"]
      let variant = latinLanguages.contains(language) ? "latin" : "multilingual"
      return root.appendingPathComponent("nemotron-multilingual/\(variant)/1120ms", isDirectory: true)
    case .parakeetTdtCtc110M, .parakeetTdtV3:
      return nil
    }
  }

  private static func requiredFiles(route: LocalTranscriptionRouteID) -> [String] {
    switch route {
    case .nemotronEnglish560, .nemotronEnglish1120:
      return Array(ModelNames.NemotronStreaming.requiredModels)
    case .nemotronMultilingual1120:
      return [
        ModelNames.NemotronMultilingualStreaming.preprocessorFile,
        ModelNames.NemotronMultilingualStreaming.encoderFile,
        ModelNames.NemotronMultilingualStreaming.decoderFile,
        ModelNames.NemotronMultilingualStreaming.jointFile,
        ModelNames.NemotronMultilingualStreaming.tokenizer,
        ModelNames.NemotronMultilingualStreaming.metadata,
      ]
    case .parakeetTdtCtc110M, .parakeetTdtV3:
      return []
    }
  }

  private static func makeBuffer(_ samples: [Float]) throws -> AVAudioPCMBuffer {
    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
      ),
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(samples.count)
      ),
      let channel = buffer.floatChannelData?[0]
    else {
      throw LocalTranscriptionError.bufferAllocationFailed
    }
    channel.update(from: samples, count: samples.count)
    buffer.frameLength = AVAudioFrameCount(samples.count)
    return buffer
  }
}
