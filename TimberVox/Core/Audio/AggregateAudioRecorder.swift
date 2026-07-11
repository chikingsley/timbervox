@preconcurrency import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
import Synchronization

final class AggregateAudioRecorder: @unchecked Sendable {
  private let logger = TimberVoxLog.audio
  private let ioQueue = DispatchQueue(
    label: "com.chiejimofor.timbervox.aggregate-audio-io",
    qos: .userInitiated
  )
  private let healthWatchdog = AggregateAudioHealthWatchdog()
  private let processingQueue = DispatchQueue(
    label: "com.chiejimofor.timbervox.aggregate-audio-processing",
    qos: .userInitiated
  )

  private var processTapID = AudioObjectID(kAudioObjectUnknown)
  private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
  private var deviceProcID: AudioDeviceIOProcID?
  private var microphoneChannelCount = 0
  private var tapChannelCount = 0
  private var sourceSampleRate = 0.0
  private var audioBridge: AggregateAudioBridge?
  private let didReportFailure = Atomic<Bool>(false)

  private var microphoneFile: AVAudioFile?
  private var systemFile: AVAudioFile?
  private var mixedFile: AVAudioFile?
  private var microphoneResampler: AggregateMonoResampler?
  private var systemResampler: AggregateMonoResampler?
  private var mixedURL: URL?
  private var microphoneURL: URL?
  private var systemURL: URL?
  private var onLevel: (@Sendable (Float) -> Void)?
  private var onSamples: (@Sendable ([Float]) -> Void)?
  private var onError: (@Sendable (Error) -> Void)?
  private(set) var captureDiagnostics = AggregateAudioCaptureDiagnostics()

  func start(
    writingTo mixedURL: URL,
    microphoneURL: URL,
    systemURL: URL,
    onLevel: (@Sendable (Float) -> Void)?,
    onSamples: (@Sendable ([Float]) -> Void)?,
    onError: (@Sendable (Error) -> Void)? = nil
  ) throws {
    guard self.mixedURL == nil else { return }

    self.mixedURL = mixedURL
    self.microphoneURL = microphoneURL
    self.systemURL = systemURL
    self.onLevel = onLevel
    self.onSamples = onSamples
    self.onError = onError
    didReportFailure.store(false, ordering: .releasing)
    captureDiagnostics = AggregateAudioCaptureDiagnostics()

    do {
      try prepareHardware()
      try prepareFiles()
      try startHardware()
      logger.notice("Aggregate microphone and system-audio recording started")
    } catch {
      cleanup(deleteFiles: true)
      throw error
    }
  }

  func finish() throws -> (url: URL, duration: TimeInterval)? {
    guard let mixedURL else { return nil }
    healthWatchdog.stop()
    try stopHardware()
    audioBridge?.stopAcceptingAudio()
    processingQueue.sync {}
    captureBridgeDiagnostics()
    let duration = mixedFile.map { Double($0.length) / AggregateAudioFormat.sampleRate } ?? 0
    closeFiles()
    destroyHardware()
    clearCallbacksAndURLs()
    logger.notice(
      "Aggregate recording finished: \(String(format: "%.1f", duration))s"
    )
    return (mixedURL, duration)
  }

  func cancel() {
    cleanup(deleteFiles: true)
  }

  private func prepareHardware() throws {
    let tapDescription = CATapDescription(monoGlobalTapButExcludeProcesses: [])
    tapDescription.uuid = UUID()
    tapDescription.name = "TimberVox Microphone and System Audio"
    tapDescription.isPrivate = true
    tapDescription.muteBehavior = .unmuted

    try check(
      AudioHardwareCreateProcessTap(tapDescription, &processTapID),
      operation: "Create microphone and system-audio process tap"
    )

    let inputDeviceID = try AudioObjectID.aggregateDefaultInputDevice()
    let inputDeviceUID = try inputDeviceID.aggregateDeviceUID()
    microphoneChannelCount = try inputDeviceID.inputChannelCount()
    let tapFormat = try processTapID.aggregateTapStreamBasicDescription()
    tapChannelCount = Int(tapFormat.mChannelsPerFrame)
    sourceSampleRate = tapFormat.mSampleRate

    let aggregateDescription: [String: Any] = [
      kAudioAggregateDeviceNameKey: "TimberVox Microphone and System Audio",
      kAudioAggregateDeviceUIDKey: UUID().uuidString,
      kAudioAggregateDeviceMainSubDeviceKey: inputDeviceUID,
      kAudioAggregateDeviceIsPrivateKey: true,
      kAudioAggregateDeviceIsStackedKey: false,
      kAudioAggregateDeviceSubDeviceListKey: [
        [
          kAudioSubDeviceUIDKey: inputDeviceUID,
          kAudioSubDeviceDriftCompensationKey: false,
        ]
      ],
      kAudioAggregateDeviceTapListKey: [
        [
          kAudioSubTapUIDKey: tapDescription.uuid.uuidString,
          kAudioSubTapDriftCompensationKey: true,
        ]
      ],
    ]
    try check(
      AudioHardwareCreateAggregateDevice(
        aggregateDescription as CFDictionary,
        &aggregateDeviceID
      ),
      operation: "Create microphone and system-audio aggregate device"
    )
    let frameSizes = try aggregateDeviceID.aggregateBufferFrameSizes()
    // Half a second absorbs ordinary scheduling jitter without allowing a
    // realtime transcription consumer to accumulate seconds of stale audio.
    let bufferedFrameCount = Int(ceil(sourceSampleRate * 0.5))
    let slotCount = max(2, bufferedFrameCount / max(1, frameSizes.current) + 2)
    audioBridge = AggregateAudioBridge(
      slotCount: slotCount,
      maximumFrameCount: frameSizes.maximum
    )
  }

  private func prepareFiles() throws {
    guard
      let mixedURL,
      let microphoneURL,
      let systemURL,
      sourceSampleRate > 0
    else {
      throw AggregateAudioRecorderError.invalidConfiguration
    }
    for url in [mixedURL, microphoneURL, systemURL] {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
    }
    microphoneFile = try AggregateAudioFormat.makeFile(at: microphoneURL)
    systemFile = try AggregateAudioFormat.makeFile(at: systemURL)
    mixedFile = try AggregateAudioFormat.makeFile(at: mixedURL)
    microphoneResampler = try AggregateMonoResampler(sourceSampleRate: sourceSampleRate)
    systemResampler = try AggregateMonoResampler(sourceSampleRate: sourceSampleRate)
  }

  private func startHardware() throws {
    let microphoneChannelCount = self.microphoneChannelCount
    let tapChannelCount = self.tapChannelCount
    guard let audioBridge else {
      throw AggregateAudioRecorderError.invalidConfiguration
    }
    processingQueue.async { [weak self, audioBridge] in
      self?.drain(audioBridge)
    }
    let ioBlock: AudioDeviceIOBlock = { _, inputData, inputTime, _, _ in
      audioBridge.push(
        inputData: inputData,
        inputTime: inputTime.pointee,
        microphoneChannelCount: microphoneChannelCount,
        tapChannelCount: tapChannelCount
      )
    }
    try check(
      AudioDeviceCreateIOProcIDWithBlock(
        &deviceProcID,
        aggregateDeviceID,
        ioQueue,
        ioBlock
      ),
      operation: "Create microphone and system-audio IOProc"
    )
    try check(
      AudioDeviceStart(aggregateDeviceID, deviceProcID),
      operation: "Start microphone and system-audio aggregate device"
    )
    healthWatchdog.start(bridge: audioBridge) { [weak self] in
      self?.reportFailure(AggregateAudioRecorderError.captureStopped)
    }
  }

  private func drain(_ bridge: AggregateAudioBridge) {
    while bridge.isAcceptingAudio || bridge.hasPendingAudio {
      if let snapshot = bridge.pop() {
        process(snapshot)
      } else {
        Thread.sleep(forTimeInterval: 0.000_5)
      }
    }
  }

  private func process(_ snapshot: AggregateInputSnapshot) {
    guard
      let microphoneResampler,
      let systemResampler
    else { return }

    do {
      let microphone = try microphoneResampler.convert(snapshot.microphoneSamples)
      let system = try systemResampler.convert(snapshot.systemSamples)
      let frameCount = max(microphone.count, system.count)
      guard frameCount > 0 else { return }

      var mixed = [Float](repeating: 0, count: frameCount)
      for index in 0..<frameCount {
        let microphoneSample = index < microphone.count ? microphone[index] : 0
        let systemSample = index < system.count ? system[index] : 0
        mixed[index] = max(-1, min(1, 0.5 * microphoneSample + 0.5 * systemSample))
      }

      try AggregateAudioFormat.write(microphone, to: microphoneFile)
      try AggregateAudioFormat.write(system, to: systemFile)
      try AggregateAudioFormat.write(mixed, to: mixedFile)
      onLevel?(AggregateAudioFormat.normalizedLevel(from: microphone))
      onSamples?(mixed)

      if AggregateAudioFormat.rootMeanSquare(system) > 0.000_1 {
        UserDefaults.standard.set(
          true,
          forKey: SystemAudioPermissionEvidence.successfulCaptureKey
        )
      }
    } catch {
      logger.error("Aggregate audio processing failed: \(error.localizedDescription)")
      reportFailure(error)
    }
  }

  private func reportFailure(_ error: Error) {
    guard !didReportFailure.exchange(true, ordering: .acquiringAndReleasing) else { return }
    logger.error("Aggregate capture failed: \(error.localizedDescription)")
    onError?(error)
  }

  private func cleanup(deleteFiles: Bool) {
    healthWatchdog.stop()
    _ = try? stopHardware()
    audioBridge?.stopAcceptingAudio()
    processingQueue.sync {}
    captureBridgeDiagnostics()
    closeFiles()
    destroyHardware()
    if deleteFiles {
      for url in [mixedURL, microphoneURL, systemURL].compactMap({ $0 }) {
        try? FileManager.default.removeItem(at: url)
      }
    }
    clearCallbacksAndURLs()
  }

  private func stopHardware() throws {
    guard aggregateDeviceID.isAggregateKnown else { return }
    try check(
      AudioDeviceStop(aggregateDeviceID, deviceProcID),
      operation: "Stop microphone and system-audio aggregate device"
    )
  }

  private func closeFiles() {
    microphoneFile = nil
    systemFile = nil
    mixedFile = nil
    microphoneResampler = nil
    systemResampler = nil
    audioBridge = nil
  }

  private func captureBridgeDiagnostics() {
    guard let audioBridge else { return }
    let diagnostics = audioBridge.diagnostics
    captureDiagnostics = diagnostics
    if diagnostics.isDegraded {
      logger.error(
        "Aggregate capture degraded: dropped \(diagnostics.droppedChunks) chunks / \(diagnostics.droppedFrames) frames; oversized \(diagnostics.oversizedChunks) chunks"
      )
    }
  }

  private func destroyHardware() {
    if aggregateDeviceID.isAggregateKnown {
      if let deviceProcID {
        _ = AudioDeviceDestroyIOProcID(aggregateDeviceID, deviceProcID)
      }
      deviceProcID = nil
      _ = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
      aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    }
    if processTapID.isAggregateKnown {
      _ = AudioHardwareDestroyProcessTap(processTapID)
      processTapID = AudioObjectID(kAudioObjectUnknown)
    }
    microphoneChannelCount = 0
    tapChannelCount = 0
    sourceSampleRate = 0
  }

  private func clearCallbacksAndURLs() {
    mixedURL = nil
    microphoneURL = nil
    systemURL = nil
    onLevel = nil
    onSamples = nil
    onError = nil
  }

  private func check(_ status: OSStatus, operation: String) throws {
    guard status == noErr else {
      throw AggregateAudioRecorderError.coreAudio(operation, status)
    }
  }
}
