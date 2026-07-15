import Foundation

enum FluidAudioModelAsset: Equatable, Hashable, Sendable {
  case batch(LocalTranscriptionRouteID)
  case realtime(LocalTranscriptionRouteID, language: String)
}

enum FluidAudioModelAssetState: Equatable, Sendable {
  case downloaded
  case missing
  case verified
}

struct FluidAudioModelPackage: Equatable, Identifiable, Sendable {
  var id: String
  var assets: [FluidAudioModelAsset]

  var estimatedDownloadBytes: Int64 {
    assets.reduce(0) { $0 + FluidAudioModelPackageCatalog.estimatedDownloadBytes(for: $1) }
  }
}

enum FluidAudioModelPackageCatalog {
  static let packages = [hummingbird, nightingale, songbird]

  static func package(id: String) -> FluidAudioModelPackage? {
    packages.first { $0.id == id }
  }

  /// Approximate bytes for the exact FluidAudio assets TimberVox installs.
  /// These values are a 2026-07-14 snapshot of the current Hugging Face files
  /// used by FluidAudio 0.15.5. They weight multi-asset package progress; the
  /// ready state continues to report the measured allocated bytes on disk.
  static func estimatedDownloadBytes(for asset: FluidAudioModelAsset) -> Int64 {
    switch asset {
    case .batch(.parakeetTdtCtc110M):
      227_448_073
    case .batch(.parakeetTdtV3):
      483_105_645
    case .realtime(.nemotronEnglish560, language: _):
      626_449_022
    case .realtime(.nemotronEnglish1120, language: _):
      626_803_815
    case .realtime(.nemotronMultilingual1120, let language):
      language == "ja" ? 664_144_423 : 611_340_223
    case .batch(.nemotronEnglish560), .batch(.nemotronEnglish1120),
      .batch(.nemotronMultilingual1120), .realtime(.parakeetTdtCtc110M, language: _),
      .realtime(.parakeetTdtV3, language: _):
      0
    }
  }

  private static let hummingbird = FluidAudioModelPackage(
    id: "local-hummingbird",
    assets: [
      .batch(.parakeetTdtCtc110M),
      .realtime(.nemotronEnglish560, language: "en"),
    ]
  )

  private static let nightingale = FluidAudioModelPackage(
    id: "local-nightingale",
    assets: [
      .batch(.parakeetTdtV3),
      .realtime(.nemotronEnglish1120, language: "en"),
    ]
  )

  private static let songbird = FluidAudioModelPackage(
    id: "local-songbird",
    assets: [
      .batch(.parakeetTdtV3),
      .realtime(.nemotronMultilingual1120, language: "en"),
      .realtime(.nemotronMultilingual1120, language: "ja"),
    ]
  )
}

enum FluidAudioModelPackageState: Equatable, Sendable {
  case checking
  case downloaded(unverified: Int)
  case downloading(FluidAudioModelPackageProgress)
  case failed(String)
  case notDownloaded
  case partial(downloaded: Int, verified: Int, total: Int)
  case ready
  case unknown
}

struct FluidAudioModelPackageProgress: Equatable, Sendable {
  let estimatedCompletedBytes: Int64
  let estimatedTotalBytes: Int64

  var fractionCompleted: Double {
    guard estimatedTotalBytes > 0 else { return 0 }
    return min(max(Double(estimatedCompletedBytes) / Double(estimatedTotalBytes), 0), 1)
  }
}

struct FluidAudioModelDownloadProgress: Equatable, Identifiable, Sendable {
  let modelID: String
  let progress: FluidAudioModelPackageProgress

  var id: String { modelID }
}

enum FluidAudioModelDownloadOutcome: Equatable, Sendable {
  case failed(String)
  case ready
}

struct FluidAudioModelDownloadResult: Equatable, Identifiable, Sendable {
  let modelID: String
  let outcome: FluidAudioModelDownloadOutcome

  var id: String { modelID }
}

protocol FluidAudioModelAssetManaging: Sendable {
  func state(of asset: FluidAudioModelAsset) async -> FluidAudioModelAssetState
  func installedBytes(of asset: FluidAudioModelAsset) async -> Int64
  func prepare(
    _ asset: FluidAudioModelAsset,
    progress: @Sendable @escaping (Double) -> Void
  ) async throws
  func delete(_ asset: FluidAudioModelAsset) async throws
}
