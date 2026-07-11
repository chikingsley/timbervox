@preconcurrency import AVFoundation
import CoreAudio
import Foundation

extension AVAudioPCMBuffer: @unchecked @retroactive Sendable {}

enum MicrophoneRecorderError: Error {
  case formatUnavailable
}

private struct MicrophoneRecorderCallbacks: Sendable {
  var onLevel: (@Sendable (Float) -> Void)?
  var onSamples: (@Sendable ([Float]) -> Void)?
}

/// Captures the microphone, resamples to 16 kHz mono (what transcription wants),
/// and writes a 16-bit WAV. Ported from old-app StreamingAudioService, plus file output.
actor MicrophoneRecorder {
  private let logger = TimberVoxLog.audio

  private var engine: AVAudioEngine?
  private var file: AVAudioFile?
  private var writeTask: Task<Void, Never>?
  private var continuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
  private var currentURL: URL?

  private let targetSampleRate: Double = 16000
  private let targetChannels: AVAudioChannelCount = 1
  private let bufferFrameCount: AVAudioFrameCount = 2560  // ~160ms at 16kHz

  func start(
    writingTo url: URL,
    onLevel: (@Sendable (Float) -> Void)? = nil,
    onSamples: (@Sendable ([Float]) -> Void)? = nil
  ) throws {
    if engine != nil {
      logger.notice("Already capturing; tearing down previous session")
      tearDownEngine()
    }

    let engine = AVAudioEngine()
    self.engine = engine

    let inputNode = engine.inputNode
    let hardwareFormat = inputNode.outputFormat(forBus: 0)
    logger.notice("Hardware input: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount)ch")

    let targetFormat = try makeTargetFormat()
    let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat)

    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let file = try makeAudioFile(at: url)
    self.file = file
    currentURL = url

    let (stream, streamContinuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()
    continuation = streamContinuation

    installTap(
      on: inputNode,
      hardwareFormat: hardwareFormat,
      targetFormat: targetFormat,
      converter: converter,
      continuation: streamContinuation,
      callbacks: MicrophoneRecorderCallbacks(onLevel: onLevel, onSamples: onSamples)
    )

    writeTask = Task { [weak self] in
      for await buffer in stream {
        await self?.write(buffer)
      }
    }

    try engine.start()
    logger.notice("Recording started → \(url.lastPathComponent)")
  }

  private func makeTargetFormat() throws -> AVAudioFormat {
    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: targetSampleRate,
        channels: targetChannels,
        interleaved: false
      )
    else {
      throw MicrophoneRecorderError.formatUnavailable
    }
    return format
  }

  private func makeAudioFile(at url: URL) throws -> AVAudioFile {
    try AVAudioFile(
      forWriting: url,
      settings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: targetSampleRate,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
      ],
      commonFormat: .pcmFormatFloat32,
      interleaved: false
    )
  }

  private func installTap(
    on inputNode: AVAudioInputNode,
    hardwareFormat: AVAudioFormat,
    targetFormat: AVAudioFormat,
    converter: AVAudioConverter?,
    continuation: AsyncStream<AVAudioPCMBuffer>.Continuation,
    callbacks: MicrophoneRecorderCallbacks
  ) {
    let bufferFrameCount = self.bufferFrameCount
    let tapBufferSize = AVAudioFrameCount(hardwareFormat.sampleRate * 0.16)
    inputNode.installTap(onBus: 0, bufferSize: tapBufferSize, format: hardwareFormat) { buffer, _ in
      guard let converter else {
        callbacks.onLevel?(Self.normalizedLevel(from: buffer))
        callbacks.onSamples?(Self.samples(from: buffer))
        continuation.yield(buffer)
        return
      }
      guard
        let converted = AVAudioPCMBuffer(
          pcmFormat: targetFormat,
          frameCapacity: bufferFrameCount
        )
      else { return }

      var error: NSError?
      let status = converter.convert(to: converted, error: &error) { _, outStatus in
        outStatus.pointee = .haveData
        return buffer
      }
      guard status != .error else { return }
      callbacks.onLevel?(Self.normalizedLevel(from: converted))
      callbacks.onSamples?(Self.samples(from: converted))
      continuation.yield(converted)
    }
  }

  /// Stop and keep the file. Returns nil if nothing was being recorded.
  func finish() async -> (url: URL, duration: TimeInterval)? {
    await drainAndStop()
    let url = currentURL
    let duration = file.map { Double($0.length) / targetSampleRate } ?? 0
    file = nil
    currentURL = nil
    guard let url else { return nil }
    logger.notice("Recording finished: \(String(format: "%.1f", duration))s")
    return (url, duration)
  }

  /// Stop and delete the file.
  func cancel() async {
    await drainAndStop()
    file = nil
    if let url = currentURL {
      try? FileManager.default.removeItem(at: url)
    }
    currentURL = nil
    logger.notice("Recording cancelled and discarded")
  }

  private func write(_ buffer: AVAudioPCMBuffer) {
    do {
      try file?.write(from: buffer)
    } catch {
      logger.error("Buffer write failed: \(error.localizedDescription)")
    }
  }

  private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Float {
    guard let channel = buffer.floatChannelData?[0] else { return 0 }
    let frameLength = Int(buffer.frameLength)
    guard frameLength > 0 else { return 0 }

    var sumSquares: Float = 0
    for index in 0..<frameLength {
      let sample = channel[index]
      sumSquares += sample * sample
    }

    let rms = sqrt(sumSquares / Float(frameLength))
    return min(1, max(0, rms * 24))
  }

  private static func samples(from buffer: AVAudioPCMBuffer) -> [Float] {
    guard let channel = buffer.floatChannelData?[0] else { return [] }
    let frameLength = Int(buffer.frameLength)
    guard frameLength > 0 else { return [] }
    return Array(UnsafeBufferPointer(start: channel, count: frameLength))
  }

  private func drainAndStop() async {
    continuation?.finish()
    continuation = nil
    engine?.inputNode.removeTap(onBus: 0)
    engine?.stop()
    engine = nil
    _ = await writeTask?.value
    writeTask = nil
  }

  private func tearDownEngine() {
    continuation?.finish()
    continuation = nil
    writeTask?.cancel()
    writeTask = nil
    engine?.inputNode.removeTap(onBus: 0)
    engine?.stop()
    engine = nil
    file = nil
    currentURL = nil
  }
}
