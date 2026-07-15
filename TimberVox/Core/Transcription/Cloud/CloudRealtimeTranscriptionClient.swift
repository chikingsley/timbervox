import Foundation

struct CloudRealtimeSessionOptions: Sendable {
  var model: String
  var language: String?
  var sampleRate = 16_000
  var encoding = "linear16"
  var interimResults = true
  var punctuate = true
}

struct CloudRealtimeTranscriptPayload: Equatable, Sendable {
  var rawPayload: [String: TranscriptionJSONValue]
  var segments: [TranscriptionTimedText]
  var sequence: Int
  var speakerTurns: [TranscriptionTimedText]
  var speechFinal: Bool
  var text: String
  var words: [TranscriptionTimedText]
}

enum CloudRealtimeTranscriptionEvent: Equatable, Sendable {
  case sessionStarted(sessionID: String, rawPayload: [String: TranscriptionJSONValue])
  case audioReceived(totalBytes: Int, rawPayload: [String: TranscriptionJSONValue])
  case interimTranscript(CloudRealtimeTranscriptPayload)
  case transcriptDelta(CloudRealtimeTranscriptPayload)
  case committedTranscript(CloudRealtimeTranscriptPayload)
  case sessionCompleted(TranscriptionArtifact)
  case sessionFailed(message: String, artifact: TranscriptionArtifact)
  case unrecognized(type: String)

}

enum CloudRealtimeClientError: LocalizedError, Equatable {
  case invalidBaseURL
  case malformedEvent(String)
  case notConnected
  case recoveryFailed(disconnect: String, recovery: String)
  case unsupportedMessage

  var errorDescription: String? {
    switch self {
    case .invalidBaseURL:
      "The realtime API URL is invalid."
    case .malformedEvent(let reason):
      "The realtime API sent a malformed event: \(reason)"
    case .notConnected:
      "The realtime API is not connected."
    case .recoveryFailed(let disconnect, let recovery):
      "Realtime disconnected (\(disconnect)); session recovery failed (\(recovery))."
    case .unsupportedMessage:
      "The realtime API sent an unsupported binary message."
    }
  }
}

actor CloudRealtimeTranscriptionClient {
  private let authorization: APIConnectorAuthorization
  private let baseURL: URL
  private let session: URLSession
  private var task: URLSessionWebSocketTask?
  private var receiveLoop: Task<Void, Never>?
  private var continuation: AsyncThrowingStream<CloudRealtimeTranscriptionEvent, Error>.Continuation?
  private var sessionID: String?
  private var terminalReceived = false

  init(
    baseURL: URL,
    session: URLSession = .shared,
    authorization: APIConnectorAuthorization = .shared
  ) {
    self.authorization = authorization
    self.baseURL = baseURL
    self.session = session
  }

  func connect(
    options: CloudRealtimeSessionOptions
  ) async throws -> AsyncThrowingStream<CloudRealtimeTranscriptionEvent, Error> {
    disconnect()

    let request = try await makeRequest(options: options)
    let task = session.webSocketTask(with: request)
    self.task = task
    sessionID = nil
    terminalReceived = false

    let (stream, continuation) = AsyncThrowingStream<CloudRealtimeTranscriptionEvent, Error>
      .makeStream()
    self.continuation = continuation
    task.resume()
    startReceiveLoop(task: task)
    return stream
  }

  func sendPCM(_ samples: [Float]) async throws {
    guard let task else { throw CloudRealtimeClientError.notConnected }
    try await task.send(.data(Self.linear16Data(from: samples)))
  }

  func requestClose() async throws {
    guard let task else { throw CloudRealtimeClientError.notConnected }
    try await task.send(.string(#"{"type":"close"}"#))
  }

  func disconnect() {
    receiveLoop?.cancel()
    receiveLoop = nil
    task?.cancel(with: .normalClosure, reason: nil)
    task = nil
    continuation?.finish()
    continuation = nil
  }

  private func startReceiveLoop(task: URLSessionWebSocketTask) {
    receiveLoop = Task { [weak self] in
      while !Task.isCancelled {
        do {
          let message = try await task.receive()
          await self?.handle(message: message)
        } catch {
          await self?.finishAfterDisconnect(error: error)
          return
        }
      }
    }
  }

  private func handle(message: URLSessionWebSocketTask.Message) {
    switch message {
    case .string(let text):
      do {
        let event = try RealtimeEventParser.parse(text)
        if case .sessionStarted(let sessionID, _) = event {
          self.sessionID = sessionID
        }
        continuation?.yield(event)
        switch event {
        case .sessionCompleted, .sessionFailed:
          terminalReceived = true
          finishStream(error: nil)
        default:
          break
        }
      } catch {
        finishStream(error: error)
      }
    case .data:
      finishStream(error: CloudRealtimeClientError.unsupportedMessage)
    @unknown default:
      finishStream(error: CloudRealtimeClientError.unsupportedMessage)
    }
  }

  private func finishStream(error: Error?) {
    if let error, !isNormalClosure(error) {
      continuation?.finish(throwing: error)
    } else {
      continuation?.finish()
    }
    continuation = nil
    receiveLoop?.cancel()
    receiveLoop = nil
    task = nil
  }

  private func finishAfterDisconnect(error: Error) async {
    if !terminalReceived, let sessionID {
      do {
        let recovered = try await recover(sessionID: sessionID)
        terminalReceived = true
        continuation?.yield(recovered)
        finishStream(error: nil)
        return
      } catch let recoveryError {
        finishStream(
          error: CloudRealtimeClientError.recoveryFailed(
            disconnect: error.localizedDescription,
            recovery: recoveryError.localizedDescription
          )
        )
        return
      }
    }
    finishStream(error: error)
  }

  private func recover(sessionID: String) async throws -> CloudRealtimeTranscriptionEvent {
    let path =
      "v1/realtime/sessions/\(sessionID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sessionID)"
    let url = baseURL.appending(path: path)
    var request = URLRequest(url: url)
    let credential = try await authorization.credential()
    request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")

    var lastError: Error?
    for attempt in 0..<3 {
      do {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
          throw URLError(.badServerResponse)
        }
        return try RealtimeRecoveryResult.event(from: data)
      } catch {
        lastError = error
        if attempt < 2 {
          try await Task.sleep(for: .milliseconds(150))
        }
      }
    }
    throw lastError ?? URLError(.cannotParseResponse)
  }

  private func isNormalClosure(_ error: Error) -> Bool {
    let nsError = error as NSError
    return nsError.domain == NSPOSIXErrorDomain && nsError.code == 57
  }

  private func makeRequest(
    options: CloudRealtimeSessionOptions
  ) async throws -> URLRequest {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      throw CloudRealtimeClientError.invalidBaseURL
    }
    components.scheme = components.scheme == "https" ? "wss" : "ws"
    components.path = "/v1/realtime"
    components.queryItems = [
      URLQueryItem(name: "model", value: options.model),
      URLQueryItem(name: "encoding", value: options.encoding),
      URLQueryItem(name: "sample_rate", value: String(options.sampleRate)),
      URLQueryItem(name: "interim_results", value: options.interimResults ? "true" : "false"),
      URLQueryItem(name: "punctuate", value: options.punctuate ? "true" : "false"),
    ]

    if let language = options.language {
      components.queryItems?.append(URLQueryItem(name: "language", value: language))
    }

    guard let url = components.url else {
      throw CloudRealtimeClientError.invalidBaseURL
    }
    var request = URLRequest(url: url)
    let credential = try await authorization.credential()
    request.setValue(
      "Bearer \(credential)",
      forHTTPHeaderField: "Authorization"
    )
    return request
  }

  private static func linear16Data(from samples: [Float]) -> Data {
    var data = Data(capacity: samples.count * MemoryLayout<Int16>.size)
    for sample in samples {
      let clamped = max(-1, min(1, sample))
      let value = Int16(clamped * Float(Int16.max))
      withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    return data
  }
}
