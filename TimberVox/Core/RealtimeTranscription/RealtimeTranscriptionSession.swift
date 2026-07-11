import Foundation

@MainActor
final class RealtimeTranscriptionSession {
  typealias ClientFactory = @MainActor () -> CloudRealtimeTranscriptionClient

  private let makeClient: ClientFactory
  private let logger = TimberVoxLog.dictation
  private var client: CloudRealtimeTranscriptionClient?
  private var eventTask: Task<Void, Never>?
  private var assembler = RealtimeTranscriptAssembler()
  private var onTranscript: (@Sendable (String) -> Void)?
  private var onError: (@Sendable (String) -> Void)?

  init(makeClient: @escaping ClientFactory) {
    self.makeClient = makeClient
  }

  func start(
    model: String,
    language: String?,
    onTranscript: @escaping @Sendable (String) -> Void,
    onError: @escaping @Sendable (String) -> Void
  ) async throws {
    await cancel()
    assembler = RealtimeTranscriptAssembler()
    self.onTranscript = onTranscript
    self.onError = onError

    let client = makeClient()
    let events = try await client.connect(
      options: CloudRealtimeSessionOptions(model: model, language: language)
    )
    self.client = client
    eventTask = Task { [weak self] in
      await self?.consume(events)
    }
  }

  func sendPCM(_ samples: [Float]) async {
    guard !samples.isEmpty, let client else { return }
    do {
      try await client.sendPCM(samples)
    } catch {
      recordError(error.localizedDescription)
      logger.notice("Realtime audio send failed: \(error.localizedDescription)")
    }
  }

  func finish() async throws -> String {
    guard let client else {
      throw TimberVoxCloudError.realtimeFailed("Realtime session was not connected.")
    }
    try? await client.requestClose()

    let deadline = Date.now.addingTimeInterval(1.5)
    while !assembler.streamEnded, Date.now < deadline {
      try? await Task.sleep(for: .milliseconds(50))
    }

    await client.disconnect()
    eventTask?.cancel()
    self.client = nil
    eventTask = nil

    let transcript = assembler.text
    let realtimeError = assembler.errorMessage
    reset()

    if let realtimeError {
      throw TimberVoxCloudError.realtimeFailed(realtimeError)
    }
    guard !transcript.isEmpty else {
      throw TimberVoxCloudError.emptyResult
    }
    return transcript
  }

  func cancel() async {
    await client?.disconnect()
    eventTask?.cancel()
    reset()
  }

  private func consume(
    _ events: AsyncThrowingStream<CloudRealtimeTranscriptionEvent, Error>
  ) async {
    do {
      for try await event in events {
        assembler.consume(event)
        onTranscript?(assembler.text)
        if let errorMessage = assembler.errorMessage {
          onError?(errorMessage)
          logger.error("Realtime provider error: \(errorMessage)")
        }
      }
    } catch {
      recordError(error.localizedDescription)
    }
  }

  private func recordError(_ message: String) {
    assembler.fail(message)
    onError?(message)
  }

  private func reset() {
    client = nil
    eventTask = nil
    assembler = RealtimeTranscriptAssembler()
    onTranscript = nil
    onError = nil
  }
}
