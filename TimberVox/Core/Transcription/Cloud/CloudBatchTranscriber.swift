import Foundation
import PeacockeryVoiceClient

/// Uploads source audio and creates a cloud batch transcription job.
struct CloudBatchTranscriber: Sendable {
  static let current = CloudBatchTranscriber(
    baseURL: APIConnector.defaultBaseURL
  )

  var api: APIConnector
  var sdk: PeacockeryVoiceSDK

  init(baseURL: URL, session: URLSession = .shared) {
    api = APIConnector(baseURL: baseURL, session: session)
    sdk = PeacockeryVoiceSDK(baseURL: baseURL)
  }

  func transcribe(
    wavAt fileURL: URL,
    model: String,
    language: String? = nil,
    diarize: Bool = false
  ) async throws -> TranscriptionArtifact {
    let sizeBytes = try fileSize(fileURL)
    let client = try await sdk.client()
    let reservationOutput = try await client.postV1Uploads(
      .init(
        body: .json(
          .init(
            contentType: "audio/wav",
            filename: fileURL.lastPathComponent,
            sizeBytes: sizeBytes
          )
        )
      )
    )
    let reservation = try uploadReservation(from: reservationOutput)
    let completedParts = try await upload(fileURL, using: reservation.transfer)
    let completionParts = completedParts.map {
      Components.Schemas.UploadCompletionRequest.PartsPayloadPayload(
        etag: $0.etag,
        partNumber: $0.partNumber
      )
    }
    let completionOutput = try await client.postV1UploadsUploadIdComplete(
      .init(
        path: .init(uploadId: reservation.uploadId),
        body: .json(.init(parts: completionParts))
      )
    )
    try validateUploadCompletion(completionOutput)

    let jobOutput = try await client.postV1Transcriptions(
      .init(
        body: .json(
          .init(
            asrModel: model,
            diarize: diarize,
            inputKey: reservation.inputKey,
            language: language,
            sync: true
          )
        )
      )
    )
    let job = try transcriptionJob(from: jobOutput)
    if let transcript = try transcriptIfTerminal(job) {
      return transcript
    }

    let deadline = Date.now.addingTimeInterval(120)
    while Date.now < deadline {
      let statusOutput = try await client.getV1JobsJobId(
        .init(path: .init(jobId: job.jobId))
      )
      let status = try transcriptionJob(from: statusOutput)
      if let transcript = try transcriptIfTerminal(status) {
        return transcript
      }
      try await Task.sleep(for: .milliseconds(400))
    }
    throw TranscriptionRuntimeError.timedOut
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
        throw APIConnectorError.invalidResponse
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
        throw APIConnectorError.invalidResponse
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
        throw APIConnectorError.invalidResponse
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
          throw TranscriptionRuntimeError.uploadFailed(error.localizedDescription)
        }
        try await Task.sleep(for: delays[attempt])
      }
    }
    throw TranscriptionRuntimeError.uploadFailed(
      lastError?.localizedDescription ?? "unknown upload error"
    )
  }

  private func isTransientUploadFailure(_ error: Error) -> Bool {
    if let apiError = error as? APIConnectorError {
      return apiError.isTransientHTTPFailure
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

  private func fileSize(_ fileURL: URL) throws -> Int {
    let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
    guard let size = values.fileSize, size > 0 else {
      throw TranscriptionRuntimeError.configuration("The recording file is empty.")
    }
    return size
  }

  private func uploadReservation(
    from output: Operations.PostV1Uploads.Output
  ) throws -> CloudUpload {
    switch output {
    case .created(let response):
      let reservation = try response.body.json
      let transfer: CloudUploadTransfer
      switch reservation.transfer {
      case .case1(let single):
        guard let url = URL(string: single.url) else {
          throw APIConnectorError.invalidResponse
        }
        transfer = .single(
          url: url,
          headers: single.headers.additionalProperties
        )
      case .case2(let multipart):
        let parts = try multipart.parts.map { part in
          guard let url = URL(string: part.url) else {
            throw APIConnectorError.invalidResponse
          }
          return CloudUploadPart(
            headers: part.headers.additionalProperties,
            partNumber: part.partNumber,
            url: url
          )
        }
        transfer = .multipart(
          partSizeBytes: multipart.partSizeBytes,
          parts: parts
        )
      }
      return CloudUpload(
        uploadId: reservation.uploadId,
        inputKey: reservation.inputKey,
        transfer: transfer
      )
    case .badRequest:
      throw APIConnectorError.httpStatus(400)
    case .unauthorized:
      throw APIConnectorError.httpStatus(401)
    case .unsupportedMediaType:
      throw APIConnectorError.httpStatus(415)
    case .undocumented(let statusCode, _):
      throw APIConnectorError.httpStatus(statusCode)
    }
  }

  private func validateUploadCompletion(
    _ output: Operations.PostV1UploadsUploadIdComplete.Output
  ) throws {
    switch output {
    case .ok:
      return
    case .badRequest:
      throw APIConnectorError.httpStatus(400)
    case .unauthorized:
      throw APIConnectorError.httpStatus(401)
    case .notFound:
      throw APIConnectorError.httpStatus(404)
    case .conflict:
      throw APIConnectorError.httpStatus(409)
    case .undocumented(let statusCode, _):
      throw APIConnectorError.httpStatus(statusCode)
    }
  }

  private func transcriptionJob(
    from output: Operations.PostV1Transcriptions.Output
  ) throws -> CloudJobStatus {
    let job: Components.Schemas.JobView
    switch output {
    case .ok(let response):
      job = try response.body.json
    case .accepted(let response):
      job = try response.body.json
    case .badRequest:
      throw APIConnectorError.httpStatus(400)
    case .unauthorized:
      throw APIConnectorError.httpStatus(401)
    case .notFound:
      throw APIConnectorError.httpStatus(404)
    case .undocumented(let statusCode, _):
      throw APIConnectorError.httpStatus(statusCode)
    }
    return try sdk.localValue(job, as: CloudJobStatus.self)
  }

  private func transcriptionJob(
    from output: Operations.GetV1JobsJobId.Output
  ) throws -> CloudJobStatus {
    let job: Components.Schemas.JobView
    switch output {
    case .ok(let response):
      job = try response.body.json
    case .unauthorized:
      throw APIConnectorError.httpStatus(401)
    case .notFound:
      throw APIConnectorError.httpStatus(404)
    case .undocumented(let statusCode, _):
      throw APIConnectorError.httpStatus(statusCode)
    }
    return try sdk.localValue(job, as: CloudJobStatus.self)
  }

  private func transcriptIfTerminal(_ status: CloudJobStatus) throws -> TranscriptionArtifact? {
    switch status.status {
    case "succeeded":
      guard let artifact = status.result else {
        throw TranscriptionRuntimeError.jobFailed("The completed job did not contain an artifact.")
      }
      return artifact
    case "failed":
      throw TranscriptionRuntimeError.jobFailed(status.error ?? "unknown error")
    default:
      return nil
    }
  }
}

private struct CompletedUploadPart {
  var etag: String
  var partNumber: Int
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

private struct CloudJobStatus: Decodable {
  var jobId: String
  var status: String
  var result: TranscriptionArtifact?
  var error: String?
}
