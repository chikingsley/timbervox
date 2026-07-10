import AVFoundation
import AppKit
import KeyboardShortcuts
import Observation

extension KeyboardShortcuts.Name {
  static let toggleDictation = Self("toggleDictation", default: .init(.space, modifiers: .option))
  static let cancelRecording = Self("cancelRecording", default: .init(.escape))
}

/// Observable UI state and user commands for dictation. Recording,
/// transcription, transformation, persistence, and delivery live in
/// `DictationWorkflow`.
@MainActor
@Observable
final class DictationController: @unchecked Sendable {
  enum State: Equatable {
    case idle
    case recording(started: Date)
    case transcribing
  }

  private(set) var state: State = .idle
  private(set) var lastRecordingURL: URL?
  private(set) var lastRecordingDuration: TimeInterval = 0
  private(set) var lastTranscript: String?
  private(set) var lastDeliveryNote: String?
  private(set) var statusMessage: String?
  private(set) var liveTranscript = ""
  private(set) var recordingLevel: CGFloat = 0

  let spectrum = AudioSpectrumMonitor()

  private let logger = TimberVoxLog.dictation
  private let workflow: DictationWorkflow
  private let pasteService = PasteService()
  @ObservationIgnored private var startTask: Task<Void, Never>?

  var isRecording: Bool {
    if case .recording = state { return true }
    return false
  }

  init(workflow: DictationWorkflow = DictationWorkflow()) {
    self.workflow = workflow
    KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
      self?.toggle()
    }
    KeyboardShortcuts.onKeyDown(for: .cancelRecording) { [weak self] in
      self?.cancelRecording()
    }
    KeyboardShortcuts.disable(.cancelRecording)
  }

  func toggle() {
    switch state {
    case .recording:
      stopAndTranscribe()
    case .idle:
      startRecording()
    case .transcribing:
      break
    }
  }

  func startRecording() {
    guard state == .idle, startTask == nil else { return }
    startTask = Task { [weak self] in
      await self?.performStartRecording()
    }
  }

  func stopAndTranscribe() {
    guard isRecording else { return }
    releaseEscapeKey()
    state = .transcribing
    Task { [weak self] in
      await self?.completeDictation()
    }
  }

  func cancelRecording() {
    guard isRecording else { return }
    releaseEscapeKey()
    state = .transcribing
    Task { [weak self] in
      await self?.workflow.cancel()
      self?.finishDictation()
    }
  }

  func copyLastTranscript() {
    guard let lastTranscript else { return }
    pasteService.copy(lastTranscript)
    lastDeliveryNote = "Copied to your clipboard"
  }

  func revealLastRecording() {
    guard let lastRecordingURL else { return }
    NSWorkspace.shared.activateFileViewerSelecting([lastRecordingURL])
  }

  private func performStartRecording() async {
    defer { startTask = nil }
    guard await ensureMicrophoneAccess() else {
      statusMessage =
        "Microphone access denied — enable TimberVox in System Settings → Privacy & Security → Microphone."
      return
    }

    do {
      prepareForRecording()
      let started = try await workflow.start(callbacks: makeWorkflowCallbacks())
      state = .recording(started: started)
      claimEscapeKey()
    } catch {
      await workflow.cancel()
      statusMessage = "Recording failed: \(error.localizedDescription)"
      logger.error("Start failed: \(error.localizedDescription)")
      finishDictation()
    }
  }

  private func completeDictation() async {
    do {
      if let outcome = try await workflow.stop() {
        lastRecordingURL = outcome.audioURL
        lastRecordingDuration = outcome.duration
        lastTranscript = outcome.finalText
        lastDeliveryNote = outcome.deliveryNote
        statusMessage = outcome.persistenceWarning
      }
    } catch {
      await workflow.cancel()
      if let workflowError = error as? DictationWorkflowError,
        let recording = workflowError.preservedRecording
      {
        lastRecordingURL = recording.url
        lastRecordingDuration = recording.duration
      }
      statusMessage = error.localizedDescription
      logger.error("Transcription failed: \(error.localizedDescription)")
    }
    finishDictation()
  }

  private func prepareForRecording() {
    liveTranscript = ""
    lastTranscript = nil
    lastDeliveryNote = nil
    statusMessage = nil
    recordingLevel = 0
    spectrum.reset()
  }

  private func finishDictation() {
    recordingLevel = 0
    liveTranscript = ""
    state = .idle
  }

  private func makeWorkflowCallbacks() -> DictationWorkflowCallbacks {
    DictationWorkflowCallbacks(
      onLevel: { [weak self] level in
        Task { @MainActor in
          self?.recordingLevel = CGFloat(level)
        }
      },
      onSamples: { [weak self] samples in
        Task { @MainActor in
          self?.spectrum.append(samples)
        }
      },
      onLiveTranscript: { [weak self] transcript in
        Task { @MainActor in
          self?.liveTranscript = transcript
        }
      },
      onRealtimeError: { [weak self] message in
        Task { @MainActor in
          self?.statusMessage = "Realtime error: \(message)"
        }
      },
      onRecordingError: { [weak self] message in
        Task { @MainActor in
          await self?.failActiveRecording(message)
        }
      }
    )
  }

  private func failActiveRecording(_ message: String) async {
    guard isRecording else { return }
    releaseEscapeKey()
    state = .transcribing
    await workflow.cancel()
    statusMessage = "Recording failed: \(message)"
    finishDictation()
  }

  private func claimEscapeKey() {
    KeyboardShortcuts.enable(.cancelRecording)
  }

  private func releaseEscapeKey() {
    KeyboardShortcuts.disable(.cancelRecording)
  }

  private func ensureMicrophoneAccess() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      return true
    case .notDetermined:
      return await AVCaptureDevice.requestAccess(for: .audio)
    default:
      return false
    }
  }
}
