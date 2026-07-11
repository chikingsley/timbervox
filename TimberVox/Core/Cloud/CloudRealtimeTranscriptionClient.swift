import Foundation

struct CloudRealtimeSessionOptions: Sendable {
  var model: String
  var language: String?
  var sampleRate = 16_000
  var encoding = "linear16"
  var interimResults = true
  var punctuate = true
}

enum CloudRealtimeTranscriptionEvent: Equatable, Sendable {
  case sessionStarted(sessionID: String)
  case audioReceived(totalBytes: Int)
  case interimTranscript(String)
  case transcriptDelta(String)
  case committedTranscript(String, start: Double?)
  case sessionCompleted(String)
  case sessionFailed(String)
  case unrecognized(type: String)
}

enum CloudRealtimeClientError: Error, Equatable {
  case invalidBaseURL
  case notConnected
}

actor CloudRealtimeTranscriptionClient {
  private let authorization: CloudAuthorization
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
    authorization: CloudAuthorization = .shared
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
      if let event = RealtimeEventParser.parse(text) {
        if case .sessionStarted(let sessionID) = event {
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
      }
    case .data:
      break
    @unknown default:
      break
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
    if !terminalReceived, let sessionID,
      let recovered = try? await recover(sessionID: sessionID)
    {
      terminalReceived = true
      continuation?.yield(recovered)
      finishStream(error: nil)
      return
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

enum RealtimeEventParser {
  static func parse(_ text: String) -> CloudRealtimeTranscriptionEvent? {
    guard
      let data = text.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }

    guard let type = object["type"] as? String else { return nil }

    switch type {
    case "session.started":
      return .sessionStarted(sessionID: object["session_id"] as? String ?? "")
    case "audio.received":
      return .audioReceived(totalBytes: object["audio_bytes"] as? Int ?? 0)
    case "transcript.interim":
      return .interimTranscript(object["text"] as? String ?? "")
    case "transcript.delta":
      return .transcriptDelta(object["text"] as? String ?? "")
    case "transcript.committed":
      let segments = object["segments"] as? [[String: Any]]
      return .committedTranscript(
        object["text"] as? String ?? "",
        start: segments?.first?["startSeconds"] as? Double
      )
    case "session.completed":
      return .sessionCompleted(object["transcript"] as? String ?? "")
    case "session.failed":
      return .sessionFailed(describe(object["error"] as Any))
    default:
      return .unrecognized(type: type)
    }
  }

  private static func describe(_ value: Any) -> String {
    if let text = value as? String {
      return text
    }
    if let dictionary = value as? [String: Any] {
      if let message = dictionary["message"] as? String {
        return message
      }
      if let data = try? JSONSerialization.data(withJSONObject: dictionary),
        let text = String(data: data, encoding: .utf8)
      {
        return text
      }
    }
    return String(describing: value)
  }
}

private enum RealtimeRecoveryResult {
  static func event(from data: Data) throws -> CloudRealtimeTranscriptionEvent {
    guard
      let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let text = String(data: data, encoding: .utf8),
      let event = RealtimeEventParser.parse(text)
    else {
      throw URLError(.cannotParseResponse)
    }
    let type = object["type"] as? String
    guard type == "session.completed" || type == "session.failed" else {
      throw URLError(.cannotParseResponse)
    }
    return event
  }
}
