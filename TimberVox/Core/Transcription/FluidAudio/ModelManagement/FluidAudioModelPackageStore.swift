import Foundation
import Observation

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
}

enum FluidAudioModelPackageCatalog {
  static let packages = [hummingbird, nightingale, songbird]

  static func package(id: String) -> FluidAudioModelPackage? {
    packages.first { $0.id == id }
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
  case downloading(progress: Double)
  case failed(String)
  case notDownloaded
  case partial(downloaded: Int, verified: Int, total: Int)
  case ready
  case unknown
}

struct FluidAudioModelDownloadProgress: Equatable, Identifiable, Sendable {
  let modelID: String
  let progress: Double

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

actor FluidAudioModelAssetBackend: FluidAudioModelAssetManaging {
  func state(of asset: FluidAudioModelAsset) async -> FluidAudioModelAssetState {
    let isDownloaded =
      switch asset {
      case .batch(let route):
        await FluidAudioBatchTranscriber.shared.isDownloaded(route: route)
      case .realtime(let route, let language):
        await FluidAudioRealtimeTranscriptionSession.shared.isDownloaded(
          route: route,
          language: language
        )
      }
    guard isDownloaded else { return .missing }
    return FileManager.default.fileExists(atPath: verificationURL(for: asset).path)
      ? .verified : .downloaded
  }

  func prepare(
    _ asset: FluidAudioModelAsset,
    progress: @Sendable @escaping (Double) -> Void
  ) async throws {
    switch asset {
    case .batch(let route):
      await FluidAudioRealtimeTranscriptionSession.shared.releaseLoadedModel()
      try await FluidAudioBatchTranscriber.shared.prepare(route: route, progress: progress)
    case .realtime(let route, let language):
      await FluidAudioBatchTranscriber.shared.releaseLoadedModel()
      try await FluidAudioRealtimeTranscriptionSession.shared.prepare(
        route: route,
        language: language,
        progress: progress
      )
    }
    let marker = verificationURL(for: asset)
    try FileManager.default.createDirectory(
      at: marker.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("verified\n".utf8).write(to: marker, options: .atomic)
  }

  func installedBytes(of asset: FluidAudioModelAsset) async -> Int64 {
    switch asset {
    case .batch(let route):
      await FluidAudioBatchTranscriber.shared.installedBytes(route: route)
    case .realtime(let route, let language):
      await FluidAudioRealtimeTranscriptionSession.shared.installedBytes(
        route: route,
        language: language
      )
    }
  }

  func delete(_ asset: FluidAudioModelAsset) async throws {
    switch asset {
    case .batch(let route):
      try await FluidAudioBatchTranscriber.shared.delete(route: route)
    case .realtime(let route, let language):
      try await FluidAudioRealtimeTranscriptionSession.shared.delete(
        route: route,
        language: language
      )
    }
    try? FileManager.default.removeItem(at: verificationURL(for: asset))
  }

  private func verificationURL(for asset: FluidAudioModelAsset) -> URL {
    let name =
      switch asset {
      case .batch(let route):
        "batch-\(route.rawValue)"
      case .realtime(let route, let language):
        "realtime-\(route.rawValue)-\(language)"
      }
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("TimberVox/LocalModels/verified-fluidaudio-0.15.5", isDirectory: true)
      .appendingPathComponent(name)
  }
}

@MainActor
@Observable
final class FluidAudioModelPackageStore {
  static let shared = FluidAudioModelPackageStore(backend: FluidAudioModelAssetBackend())

  private let backend: any FluidAudioModelAssetManaging
  private(set) var states: [String: FluidAudioModelPackageState] = [:]
  private(set) var installedByteCounts: [String: Int64] = [:]
  private(set) var downloadResults: [String: FluidAudioModelDownloadOutcome] = [:]

  init(backend: any FluidAudioModelAssetManaging) {
    self.backend = backend
  }

  func state(for modelID: String) -> FluidAudioModelPackageState {
    states[modelID] ?? .unknown
  }

  func installedBytes(for modelID: String) -> Int64 {
    installedByteCounts[modelID] ?? 0
  }

  var activeDownloads: [FluidAudioModelDownloadProgress] {
    states.compactMap { modelID, state in
      guard case .downloading(let progress) = state else { return nil }
      return FluidAudioModelDownloadProgress(modelID: modelID, progress: progress)
    }
    .sorted { $0.modelID < $1.modelID }
  }

  var recentDownloadResults: [FluidAudioModelDownloadResult] {
    downloadResults.map { modelID, outcome in
      FluidAudioModelDownloadResult(modelID: modelID, outcome: outcome)
    }
    .sorted { $0.modelID < $1.modelID }
  }

  func refresh(modelID: String) async {
    guard let package = FluidAudioModelPackageCatalog.package(id: modelID) else { return }
    states[modelID] = .checking
    await updateResolvedSnapshot(for: package)
  }

  func refreshAll() async {
    for package in FluidAudioModelPackageCatalog.packages {
      states[package.id] = .checking
    }
    for package in FluidAudioModelPackageCatalog.packages {
      await updateResolvedSnapshot(for: package)
    }
  }

  func download(modelID: String) async {
    guard let package = FluidAudioModelPackageCatalog.package(id: modelID) else { return }
    if case .some(.downloading) = states[modelID] { return }
    if activeDownloads.isEmpty {
      downloadResults.removeAll()
    }
    downloadResults[modelID] = nil
    states[modelID] = .downloading(progress: 0)
    do {
      let assetCount = Double(package.assets.count)
      for (index, asset) in package.assets.enumerated() {
        if await backend.state(of: asset) == .verified { continue }
        let completedAssets = Double(index)
        try await backend.prepare(asset) { [weak self] assetProgress in
          Task { @MainActor in
            self?.states[modelID] = .downloading(
              progress: (completedAssets + assetProgress) / assetCount
            )
          }
        }
      }
      await updateResolvedSnapshot(for: package)
      downloadResults[modelID] = .ready
    } catch {
      states[modelID] = .failed(error.localizedDescription)
      downloadResults[modelID] = .failed(error.localizedDescription)
    }
  }

  func dismissDownloadResults() {
    downloadResults.removeAll()
  }

  func delete(modelID: String) async {
    guard let package = FluidAudioModelPackageCatalog.package(id: modelID) else { return }
    do {
      let retainedAssets = await assetsRequiredByOtherInstalledPackages(excluding: modelID)
      for asset in package.assets where !retainedAssets.contains(asset) {
        try await backend.delete(asset)
      }
      await refreshAll()
    } catch {
      states[modelID] = .failed(error.localizedDescription)
    }
  }

  private func resolvedState(
    for package: FluidAudioModelPackage
  ) async -> FluidAudioModelPackageState {
    var downloaded = 0
    var verified = 0
    for asset in package.assets {
      switch await backend.state(of: asset) {
      case .missing:
        break
      case .downloaded:
        downloaded += 1
      case .verified:
        downloaded += 1
        verified += 1
      }
    }
    if verified == package.assets.count { return .ready }
    if downloaded == package.assets.count {
      return .downloaded(unverified: downloaded - verified)
    }
    if downloaded == 0 { return .notDownloaded }
    return .partial(downloaded: downloaded, verified: verified, total: package.assets.count)
  }

  private func updateResolvedSnapshot(for package: FluidAudioModelPackage) async {
    var byteCount: Int64 = 0
    for asset in package.assets {
      byteCount += await backend.installedBytes(of: asset)
    }
    installedByteCounts[package.id] = byteCount
    states[package.id] = await resolvedState(for: package)
  }

  private func assetsRequiredByOtherInstalledPackages(
    excluding modelID: String
  ) async -> Set<FluidAudioModelAsset> {
    var retained: Set<FluidAudioModelAsset> = []
    for package in FluidAudioModelPackageCatalog.packages where package.id != modelID {
      var isInstalled = true
      for asset in package.assets where await backend.state(of: asset) == .missing {
        isInstalled = false
      }
      if isInstalled {
        retained.formUnion(package.assets)
      }
    }
    return retained
  }
}

enum FluidAudioModelStorage {
  static func allocatedBytes(at directory: URL) -> Int64 {
    let keys: Set<URLResourceKey> = [
      .fileAllocatedSizeKey,
      .fileSizeKey,
      .isRegularFileKey,
      .totalFileAllocatedSizeKey,
    ]
    guard
      let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: Array(keys),
        options: []
      )
    else { return 0 }

    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
      let isRegularFile = values.isRegularFile ?? false
      guard isRegularFile else { continue }
      total += Int64(
        values.totalFileAllocatedSize
          ?? values.fileAllocatedSize
          ?? values.fileSize
          ?? 0
      )
    }
    return total
  }
}
