import Foundation

struct TranscriptionOutcome: Sendable {
  let rawText: String
  let text: String
  let provider: String?
  let providerLatencyMs: Double?
  let language: String?
}

/// Uploads source audio and creates a cloud batch transcription job.
struct CloudBatchTranscriptionClient: Sendable {
  static let production = CloudBatchTranscriptionClient(
    baseURL: CloudHTTPClient.productionBaseURL
  )

  var api: CloudHTTPClient

  init(baseURL: URL, session: URLSession = .shared) {
    api = CloudHTTPClient(baseURL: baseURL, session: session)
  }

  func transcribe(
    wavAt fileURL: URL,
    model: String,
    language: String? = nil,
    diarize: Bool = false
  ) async throws -> TranscriptionOutcome {
    let sizeBytes = try fileSize(fileURL)
    let reservation: CloudUpload = try await api.post(
      path: "v1/uploads",
      body: CreateUploadRequest(
        filename: fileURL.lastPathComponent,
        contentType: "audio/wav",
        sizeBytes: sizeBytes
      )
    )
    let completedParts = try await upload(fileURL, using: reservation.transfer)
    let _: CloudUploadCompletion = try await api.post(
      path: "v1/uploads/\(reservation.uploadId)/complete",
      body: CompleteUploadRequest(parts: completedParts)
    )

    let job: CloudJobStatus = try await api.post(
      path: "v1/transcriptions",
      body: CreateTranscriptionRequest(
        asrModel: model,
        diarize: diarize,
        inputKey: reservation.inputKey,
        language: language,
        sync: true
      )
    )
    if let transcript = try transcriptIfTerminal(job) {
      return transcript
    }

    let deadline = Date.now.addingTimeInterval(120)
    while Date.now < deadline {
      let status: CloudJobStatus = try await api.get(path: "v1/jobs/\(job.jobId)")
      if let transcript = try transcriptIfTerminal(status) {
        return transcript
      }
      try await Task.sleep(for: .milliseconds(400))
    }
    throw TimberVoxCloudError.timedOut
  }

  private func upload(
    _ fileURL: URL,
    using transfer: CloudUploadTransfer
  ) async throws -> [CompletedUploadPart] {
    switch transfer {
    case .single(let url, let headers):
      _ = try await retryUpload {
        try await api.upload(
          fileAt: fileURL,
          to: url,
          headers: headers,
          timeout: 180
        )
      }
      return []
    case .multipart(let partSizeBytes, let parts):
      guard !parts.isEmpty else {
        throw TimberVoxCloudError.invalidResponse
      }
      return try await uploadParts(
        fileURL,
        partSizeBytes: partSizeBytes,
        parts: parts
      )
    }
  }

  private func uploadParts(
    _ fileURL: URL,
    partSizeBytes: Int,
    parts: [CloudUploadPart]
  ) async throws -> [CompletedUploadPart] {
    let file = try FileHandle(forReadingFrom: fileURL)
    defer { try? file.close() }
    var completed: [CompletedUploadPart] = []
    for part in parts.sorted(using: KeyPathComparator(\.partNumber)) {
      guard let data = try file.read(upToCount: partSizeBytes), !data.isEmpty else {
        throw TimberVoxCloudError.invalidResponse
      }
      let uploadedETag = try await retryUpload {
        try await api.upload(
          data: data,
          to: part.url,
          headers: part.headers,
          timeout: 180
        )
      }
      guard let etag = uploadedETag else {
        throw TimberVoxCloudError.invalidResponse
      }
      completed.append(CompletedUploadPart(etag: etag, partNumber: part.partNumber))
    }
    return completed
  }

  private func retryUpload<Result: Sendable>(
    operation: @Sendable () async throws -> Result
  ) async throws -> Result {
    let delays: [Duration] = [.milliseconds(250), .milliseconds(750)]
    var lastError: Error?
    for attempt in 0...delays.count {
      do {
        return try await operation()
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        lastError = error
        guard attempt < delays.count, isTransientUploadFailure(error) else {
          throw TimberVoxCloudError.uploadFailed(error.localizedDescription)
        }
        try await Task.sleep(for: delays[attempt])
      }
    }
    throw TimberVoxCloudError.uploadFailed(
      lastError?.localizedDescription ?? "unknown upload error"
    )
  }

  private func isTransientUploadFailure(_ error: Error) -> Bool {
    if let cloudError = error as? TimberVoxCloudError {
      return cloudError.isTransientUploadFailure
    }
    guard let urlError = error as? URLError else { return false }
    return [
      .cannotConnectToHost,
      .cannotFindHost,
      .dnsLookupFailed,
      .networkConnectionLost,
      .notConnectedToInternet,
      .resourceUnavailable,
      .timedOut,
    ].contains(urlError.code)
  }

  private func fileSize(_ fileURL: URL) throws -> Int64 {
    let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
    guard let size = values.fileSize, size > 0 else {
      throw TimberVoxCloudError.configuration("The recording file is empty.")
    }
    return Int64(size)
  }

  private func transcriptIfTerminal(_ status: CloudJobStatus) throws -> TranscriptionOutcome? {
    switch status.status {
    case "succeeded":
      guard let transcript = status.result?.transcript, !transcript.isEmpty else {
        throw TimberVoxCloudError.emptyResult
      }
      return TranscriptionOutcome(
        rawText: status.result?.rawTranscript ?? transcript,
        text: transcript,
        provider: status.result?.asr?.provider,
        providerLatencyMs: status.result?.asr?.providerLatencyMs,
        language: status.result?.asr?.language
      )
    case "failed":
      throw TimberVoxCloudError.jobFailed(status.error ?? "unknown error")
    default:
      return nil
    }
  }
}

private struct CreateUploadRequest: Encodable {
  var filename: String
  var contentType: String
  var sizeBytes: Int64
}

private struct CompleteUploadRequest: Encodable {
  var parts: [CompletedUploadPart]
}

private struct CompletedUploadPart: Encodable {
  var etag: String
  var partNumber: Int
}

private struct CreateTranscriptionRequest: Encodable {
  var asrModel: String
  var diarize: Bool
  var inputKey: String
  var language: String?
  var sync: Bool
}

private struct CloudUpload: Decodable {
  var uploadId: String
  var inputKey: String
  var transfer: CloudUploadTransfer
}

private enum CloudUploadTransfer: Decodable {
  case multipart(partSizeBytes: Int, parts: [CloudUploadPart])
  case single(url: URL, headers: [String: String])

  private enum CodingKeys: String, CodingKey {
    case headers
    case kind
    case partSizeBytes
    case parts
    case url
  }

  private enum Kind: String, Decodable {
    case multipart
    case single
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .single:
      self = try .single(
        url: container.decode(URL.self, forKey: .url),
        headers: container.decode([String: String].self, forKey: .headers)
      )
    case .multipart:
      self = try .multipart(
        partSizeBytes: container.decode(Int.self, forKey: .partSizeBytes),
        parts: container.decode([CloudUploadPart].self, forKey: .parts)
      )
    }
  }
}

private struct CloudUploadPart: Decodable {
  var headers: [String: String]
  var partNumber: Int
  var url: URL
}

private struct CloudUploadCompletion: Decodable {
  var inputKey: String
  var sizeBytes: Int64
}

private struct CloudJobStatus: Decodable {
  var jobId: String
  var status: String
  var result: CloudTranscriptionResult?
  var error: String?
}

private struct CloudTranscriptionResult: Decodable {
  var rawTranscript: String?
  var transcript: String?
  var asr: CloudAsrInfo?
}

private struct CloudAsrInfo: Decodable {
  var provider: String?
  var providerLatencyMs: Double?
  var language: String?
}
