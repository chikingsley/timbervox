import AVFoundation
import CoreAudio
import Foundation
import ToyLocalCore

private let recordingLogger = ToyLocalLog.recording

/// Represents an audio input device
struct AudioInputDevice: Identifiable, Equatable {
  var id: String
  var legacyID: String
  var name: String
}

/// Simple structure representing audio metering values.
struct Meter: Equatable {
  let averagePower: Double
  let peakPower: Double
}

actor RecordingClientLive {
  struct AudioHardwareObserver {
    let selector: AudioObjectPropertySelector
    let reason: String
    let listener: CoreAudioPropertyListenerBlock
  }

  enum RecordingBackend: String {
    case captureEngine = "capture-engine"
    case recorderFallback = "recorder-fallback"
  }

  struct ActiveRecordingSession {
    let startedAt: Date
    let mode: CaptureRecordingMode
    let backend: RecordingBackend
  }

  var recorder: AVAudioRecorder?
  private var systemAudioRecorder: SystemAudioTapRecorder?
  let recordingURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")
  var isRecorderPrimedForNextSession = false
  var lastPrimedDeviceID: AudioDeviceID?
  var recordingSessionID: UUID?
  var activeRecordingSession: ActiveRecordingSession?
  var lastRecordingEndedAt: Date?
  var deferredCaptureRestartReason: String?
  var environmentChangeDebounceTask: Task<Void, Never>?
  var mediaControlTask: Task<Void, Never>?
  let recorderSettings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 16000.0,
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 32,
    AVLinearPCMIsFloatKey: true,
    AVLinearPCMIsBigEndianKey: false,
    AVLinearPCMIsNonInterleaved: false,
  ]
  private let (meterStream, meterContinuation) = AsyncStream<Meter>.makeStream()
  private var meterTask: Task<Void, Never>?
  lazy var captureController = CaptureEngineController(meterContinuation: meterContinuation) { [weak self] in
    Task {
      await self?.enqueueCaptureEnvironmentChange(reason: "capture-engine-configuration-changed")
    }
  }
  var captureControllerDeviceID: AudioDeviceID?
  var captureControllerNeedsRestartReason: String?
  var notificationObservers: [NSObjectProtocol] = []
  var audioHardwareObservers: [AudioHardwareObserver] = []
  var isObservingSystemChanges = false

  let settingsManager: SettingsManager

  /// Tracks whether media was paused using the media key when recording started.
  var didPauseMedia: Bool = false

  /// Tracks whether media was toggled via MediaRemote
  var didPauseViaMediaRemote: Bool = false

  /// Tracks which specific media players were paused
  var pausedPlayers: [String] = []

  /// Tracks previous system volume when muted for recording
  var previousVolume: Float?

  /// Tracks previous input volume when auto-raised for recording
  var previousInputVolume: Float?

  init(settingsManager: SettingsManager) {
    self.settingsManager = settingsManager
  }
}

extension RecordingClientLive {
  /// Gets all available input devices on the system
  func getAvailableInputDevices() async -> [AudioInputDevice] {
    let devices = RecordingAudioHardware.getAllAudioDevices()
    var inputDevices: [AudioInputDevice] = []

    for device in devices where RecordingAudioHardware.deviceHasInput(deviceID: device) {
      guard let name = RecordingAudioHardware.getDeviceName(deviceID: device) else { continue }
      let uid = RecordingAudioHardware.getDeviceUID(deviceID: device) ?? String(device)
      inputDevices.append(AudioInputDevice(id: uid, legacyID: String(device), name: name))
    }

    return inputDevices
  }

  /// Gets the current system default input device name
  func getDefaultInputDeviceName() async -> String? {
    guard let deviceID = RecordingAudioHardware.getDefaultInputDevice() else { return nil }
    return RecordingAudioHardware.getDeviceName(deviceID: deviceID)
  }

  func requestMicrophoneAccess() async -> Bool {
    await AVCaptureDevice.requestAccess(for: .audio)
  }

  func startRecording() async {
    let settings = await settingsManager.settings
    if settings.recordingInputMode == .systemAudio {
      startSystemAudioRecording()
      return
    }

    let sessionID = beginRecordingSession()
    scheduleMediaControlTask(for: settings.recordingAudioBehavior, sessionID: sessionID)

    let activeInputDevice = applyPreferredInputDevice(settings: settings)
    RecordingAudioHardware.ensureInputDeviceUnmuted()

    if settings.autoIncreaseMicrophoneVolume, settings.selectedMicrophoneID == nil {
      previousInputVolume = RecordingAudioHardware.raiseInputVolumeToMax()
    }

    let mode = captureMode(for: settings)
    logRecordingStartRequest(mode: mode, inputDeviceID: activeInputDevice)
    let startRequestAt = Date()

    do {
      try ensureCaptureControllerReadyAfterDeferredRestart(for: activeInputDevice, reason: "startRecording", mode: mode)
      let captureURL = makeCaptureRecordingURL()
      try captureController.beginRecording(to: captureURL, requestedAt: startRequestAt, mode: mode)
      let startedAt = Date()
      activeRecordingSession = ActiveRecordingSession(startedAt: startedAt, mode: mode, backend: .captureEngine)
      let startupDetails = "startup=\(self.formatDuration(startedAt.timeIntervalSince(startRequestAt)))"
      recordingLogger.notice(
        "Recording started mode=\(mode.rawValue) backend=\(RecordingBackend.captureEngine.rawValue) \(startupDetails)"
      )
      return
    } catch {
      let failureDetails = "\(error.localizedDescription); falling back to AVAudioRecorder"
      recordingLogger.error("Failed to start capture engine for mode=\(mode.rawValue): \(failureDetails)")
      stopCaptureController(reason: "capture-engine-start-failed")
    }

    do {
      let recorder = try ensureRecorderReadyForRecording()
      let recordCallStartedAt = Date()
      guard recorder.record() else {
        recordingLogger.error("AVAudioRecorder refused to start recording")
        endRecordingSession()
        return
      }
      let startedAt = Date()
      activeRecordingSession = ActiveRecordingSession(startedAt: startedAt, mode: mode, backend: .recorderFallback)
      startMeterTask()
      let recordCallDetails = "recordCall=\(self.formatDuration(Date().timeIntervalSince(recordCallStartedAt)))"
      recordingLogger.notice(
        "Recording started mode=\(mode.rawValue) backend=\(RecordingBackend.recorderFallback.rawValue) \(recordCallDetails)"
      )
    } catch {
      recordingLogger.error("Failed to start recording: \(error.localizedDescription)")
      clearActiveRecordingMetadata()
      endRecordingSession()
    }
  }

  private func startSystemAudioRecording() {
    _ = beginRecordingSession()
    invalidatePrimedState()
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("toy-local-system-audio-\(UUID().uuidString).wav")
    let recorder = SystemAudioTapRecorder(meterContinuation: meterContinuation)
    do {
      try recorder.startRecording(to: outputURL)
      systemAudioRecorder = recorder
    } catch {
      systemAudioRecorder = nil
      endRecordingSession()
      recordingLogger.error("Failed to start system audio recording: \(error.localizedDescription)")
    }
  }

  func stopRecording() async -> URL {
    if let systemAudioRecorder {
      self.systemAudioRecorder = nil
      endRecordingSession()
      lastRecordingEndedAt = Date()
      do {
        let url = try systemAudioRecorder.stopRecording()
        recordingLogger.notice("System audio recording stopped")
        return url
      } catch {
        recordingLogger.error("Failed to stop system audio recording: \(error.localizedDescription)")
        return recordingURL
      }
    }

    let settings = await settingsManager.settings
    let stopSessionID = recordingSessionID
    let activeSession = activeRecordingSession

    if activeSession?.backend == .captureEngine || captureController.isRecording {
      let stopTimingEstimate = captureController.stopTimingEstimate
      let graceDetails =
        "callbackInterval=\(self.formatDuration(stopTimingEstimate.callbackInterval)) "
        + "bufferDuration=\(self.formatDuration(stopTimingEstimate.bufferDuration))"
      recordingLogger.debug(
        "Waiting \(self.formatDuration(stopTimingEstimate.gracePeriod)) before finalizing capture-engine recording \(graceDetails)"
      )
      try? await Task.sleep(for: .milliseconds(Int((stopTimingEstimate.gracePeriod * 1000).rounded())))

      if Self.shouldIgnoreStopRequest(snapshotSessionID: stopSessionID, currentSessionID: recordingSessionID) {
        recordingLogger.notice("Ignoring stale stop request after a newer recording session started")
        return makeIgnoredStopURL()
      }
    }

    if let captureURL = captureController.finishRecording(clearBuffer: captureMode(for: settings) == .superFast) {
      return await finishCaptureEngineStop(captureURL: captureURL, activeSession: activeSession, settings: settings)
    }

    return await finishFallbackStop(activeSession: activeSession, settings: settings)
  }

  private func finishCaptureEngineStop(
    captureURL: URL,
    activeSession: ActiveRecordingSession?,
    settings: ToyLocalSettings
  ) async -> URL {
    let stoppedAt = Date()
    let session =
      activeSession
      ?? ActiveRecordingSession(startedAt: stoppedAt, mode: captureMode(for: settings), backend: .captureEngine)
    stopMeterTask()
    endRecordingSession()
    clearActiveRecordingMetadata()
    lastRecordingEndedAt = stoppedAt
    logRecordingStopped(session: session, stoppedAt: stoppedAt)

    if !settings.superFastModeEnabled {
      stopCaptureController(reason: "mode-disabled-after-stop")
      releaseRecorder(reason: "capture-engine-stop")
    }

    await flushDeferredCaptureRestartIfNeeded()
    await resumeMediaIfNeeded()
    return captureURL
  }

  private func finishFallbackStop(
    activeSession: ActiveRecordingSession?,
    settings: ToyLocalSettings
  ) async -> URL {
    let stoppedAt = Date()
    let session =
      activeSession
      ?? ActiveRecordingSession(startedAt: stoppedAt, mode: captureMode(for: settings), backend: .recorderFallback)
    let wasRecording = recorder?.isRecording == true
    guard session.backend == .recorderFallback, wasRecording else {
      recordingLogger.notice("stopRecording() called without an active recorder fallback; skipping stale recording.wav export")
      stopMeterTask()
      endRecordingSession()
      clearActiveRecordingMetadata()
      lastRecordingEndedAt = stoppedAt
      await flushDeferredCaptureRestartIfNeeded()
      await resumeMediaIfNeeded()
      return makeIgnoredStopURL()
    }
    recorder?.stop()
    stopMeterTask()
    endRecordingSession()
    clearActiveRecordingMetadata()
    lastRecordingEndedAt = stoppedAt
    logRecordingStopped(session: session, stoppedAt: stoppedAt)

    var exportedURL = recordingURL
    do {
      exportedURL = try duplicateCurrentRecording()
    } catch {
      isRecorderPrimedForNextSession = false
      recordingLogger.error("Failed to copy recording: \(error.localizedDescription)")
    }
    releaseRecorder(reason: "fallback-stop")

    if !settings.superFastModeEnabled {
      stopCaptureController(reason: "standard-stop")
    }

    await flushDeferredCaptureRestartIfNeeded()
    await resumeMediaIfNeeded()

    return exportedURL
  }

  private func logRecordingStopped(session: ActiveRecordingSession, stoppedAt: Date) {
    let stopDetails = "duration=\(self.formatDuration(stoppedAt.timeIntervalSince(session.startedAt)))"
    recordingLogger.notice(
      "Recording stopped mode=\(session.mode.rawValue) backend=\(session.backend.rawValue) \(stopDetails)"
    )
  }

  func isCurrentSession(_ sessionID: UUID) -> Bool {
    recordingSessionID == sessionID
  }

  nonisolated static func shouldIgnoreStopRequest(
    snapshotSessionID: UUID?,
    currentSessionID: UUID?
  ) -> Bool {
    guard let snapshotSessionID else { return false }
    return currentSessionID != snapshotSessionID
  }

  private func beginRecordingSession() -> UUID {
    let sessionID = UUID()
    recordingSessionID = sessionID
    mediaControlTask?.cancel()
    mediaControlTask = nil
    return sessionID
  }

  func endRecordingSession() {
    recordingSessionID = nil
    mediaControlTask?.cancel()
    mediaControlTask = nil
  }

  func clearActiveRecordingMetadata() {
    activeRecordingSession = nil
  }

  func invalidatePrimedState() {
    isRecorderPrimedForNextSession = false
    lastPrimedDeviceID = nil
  }

  func captureMode(for settings: ToyLocalSettings) -> CaptureRecordingMode {
    settings.superFastModeEnabled ? .superFast : .standard
  }

  func resolvePreferredInputDevice(settings: ToyLocalSettings) -> AudioDeviceID? {
    guard let selectedMicrophoneID = settings.selectedMicrophoneID else { return nil }
    if let deviceID = RecordingAudioHardware.getDeviceID(uid: selectedMicrophoneID),
      RecordingAudioHardware.deviceHasInput(deviceID: deviceID)
    {
      return deviceID
    }

    if let legacyDeviceID = AudioDeviceID(selectedMicrophoneID),
      RecordingAudioHardware.deviceHasInput(deviceID: legacyDeviceID)
    {
      return legacyDeviceID
    }

    recordingLogger.notice("Selected device \(selectedMicrophoneID) missing; using system default")
    return nil
  }

  @discardableResult
  func applyPreferredInputDevice(settings: ToyLocalSettings) -> AudioDeviceID? {
    let targetDeviceID = resolvePreferredInputDevice(settings: settings)
    let currentDefaultDevice = RecordingAudioHardware.getDefaultInputDevice()

    if let primedDevice = lastPrimedDeviceID, primedDevice != currentDefaultDevice {
      recordingLogger.notice("Default input changed from \(primedDevice) to \(currentDefaultDevice ?? 0); invalidating primed state")
      invalidatePrimedState()
    }

    if let targetDeviceID {
      if targetDeviceID != currentDefaultDevice {
        recordingLogger.notice("Switching input device from \(currentDefaultDevice ?? 0) to \(targetDeviceID)")
        RecordingAudioHardware.setInputDevice(deviceID: targetDeviceID)
        invalidatePrimedState()
      } else {
        recordingLogger.debug("Device \(targetDeviceID) already set as default, skipping setInputDevice()")
      }
    } else {
      recordingLogger.debug("Using system default microphone")
    }

    return RecordingAudioHardware.getDefaultInputDevice()
  }

  private func makeCaptureRecordingURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("toy-local-capture-\(UUID().uuidString).wav")
  }

  func makeIgnoredStopURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("toy-local-ignored-stop-\(UUID().uuidString).wav")
  }

  func startMeterTask() {
    meterTask = Task {
      while !Task.isCancelled, let r = self.recorder, r.isRecording {
        r.updateMeters()
        let averagePower = r.averagePower(forChannel: 0)
        let averageNormalized = pow(10, averagePower / 20.0)
        let peakPower = r.peakPower(forChannel: 0)
        let peakNormalized = pow(10, peakPower / 20.0)
        meterContinuation.yield(Meter(averagePower: Double(averageNormalized), peakPower: Double(peakNormalized)))
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  func stopMeterTask() {
    meterTask?.cancel()
    meterTask = nil
  }

  func observeAudioLevel() -> AsyncStream<Meter> {
    meterStream
  }

  func warmUpRecorder() async {
    guard activeRecordingSession == nil, recorder?.isRecording != true, !captureController.isRecording else {
      recordingLogger.notice("Skipping recorder warm-up while recording is active")
      return
    }
    let settings = await settingsManager.settings
    let activeInputDevice = applyPreferredInputDevice(settings: settings)

    if settings.superFastModeEnabled {
      releaseRecorder(reason: "warm-up-super-fast")
      do {
        try ensureCaptureControllerReadyAfterDeferredRestart(
          for: activeInputDevice,
          reason: "warmUpRecorder",
          mode: .superFast
        )
      } catch {
        recordingLogger.error("Failed to arm capture engine for super fast mode: \(error.localizedDescription)")
      }
      return
    }

    stopCaptureController(reason: "warm-up-standard")
    releaseRecorder(reason: "warm-up-standard")
    recordingLogger.debug("Standard mode uses on-demand capture engine startup; skipping idle recorder priming")
  }

  /// Release recorder resources. Call on app termination.
  func cleanup() async {
    endRecordingSession()
    await resumeMediaIfNeeded()
    stopObservingSystemChanges()
    systemAudioRecorder?.cleanup()
    systemAudioRecorder = nil
    stopCaptureController(reason: "cleanup")
    releaseRecorder(reason: "cleanup")
    recordingLogger.notice("RecordingClient cleaned up")
  }
}
