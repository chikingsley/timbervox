import Foundation
import Observation

enum LocalModelAsset: Equatable, Hashable, Sendable {
  case batch(LocalTranscriptionRouteID)
  case realtime(LocalTranscriptionRouteID, language: String)
}

enum LocalModelAssetState: Equatable, Sendable {
  case downloaded
  case missing
  case verified
}

struct LocalModelPackageDefinition: Equatable, Identifiable, Sendable {
  var id: String
  var assets: [LocalModelAsset]
}

enum LocalModelPackageCatalog {
  static let packages = [hummingbird, nightingale, songbird]

  static func package(id: String) -> LocalModelPackageDefinition? {
    packages.first { $0.id == id }
  }

  private static let hummingbird = LocalModelPackageDefinition(
    id: "local-hummingbird",
    assets: [
      .batch(.parakeetTdtCtc110M),
      .realtime(.nemotronEnglish560, language: "en"),
    ]
  )

  private static let nightingale = LocalModelPackageDefinition(
    id: "local-nightingale",
    assets: [
      .batch(.parakeetTdtV3),
      .realtime(.nemotronEnglish1120, language: "en"),
    ]
  )

  private static let songbird = LocalModelPackageDefinition(
    id: "local-songbird",
    assets: [
      .batch(.parakeetTdtV3),
      .realtime(.nemotronMultilingual1120, language: "en"),
      .realtime(.nemotronMultilingual1120, language: "ja"),
    ]
  )
}

enum LocalModelPackageState: Equatable, Sendable {
  case checking
  case downloaded(unverified: Int)
  case downloading(progress: Double)
  case failed(String)
  case notDownloaded
  case partial(downloaded: Int, verified: Int, total: Int)
  case ready
  case unknown
}

protocol LocalModelAssetBackend: Sendable {
  func state(of asset: LocalModelAsset) async -> LocalModelAssetState
  func prepare(
    _ asset: LocalModelAsset,
    progress: @Sendable @escaping (Double) -> Void
  ) async throws
  func delete(_ asset: LocalModelAsset) async throws
}

actor FluidAudioLocalModelAssetBackend: LocalModelAssetBackend {
  func state(of asset: LocalModelAsset) async -> LocalModelAssetState {
    let isDownloaded =
      switch asset {
      case .batch(let route):
        await LocalBatchTranscriptionClient.shared.isDownloaded(route: route)
      case .realtime(let route, let language):
        await LocalRealtimeTranscriptionSession.shared.isDownloaded(
          route: route,
          language: language
        )
      }
    guard isDownloaded else { return .missing }
    return FileManager.default.fileExists(atPath: verificationURL(for: asset).path)
      ? .verified : .downloaded
  }

  func prepare(
    _ asset: LocalModelAsset,
    progress: @Sendable @escaping (Double) -> Void
  ) async throws {
    switch asset {
    case .batch(let route):
      await LocalRealtimeTranscriptionSession.shared.releaseLoadedModel()
      try await LocalBatchTranscriptionClient.shared.prepare(route: route, progress: progress)
    case .realtime(let route, let language):
      await LocalBatchTranscriptionClient.shared.releaseLoadedModel()
      try await LocalRealtimeTranscriptionSession.shared.prepare(
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

  func delete(_ asset: LocalModelAsset) async throws {
    switch asset {
    case .batch(let route):
      try await LocalBatchTranscriptionClient.shared.delete(route: route)
    case .realtime(let route, let language):
      try await LocalRealtimeTranscriptionSession.shared.delete(
        route: route,
        language: language
      )
    }
    try? FileManager.default.removeItem(at: verificationURL(for: asset))
  }

  private func verificationURL(for asset: LocalModelAsset) -> URL {
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
final class LocalModelPackageStore {
  static let shared = LocalModelPackageStore(backend: FluidAudioLocalModelAssetBackend())

  private let backend: any LocalModelAssetBackend
  private(set) var states: [String: LocalModelPackageState] = [:]

  init(backend: any LocalModelAssetBackend) {
    self.backend = backend
  }

  func state(for modelID: String) -> LocalModelPackageState {
    states[modelID] ?? .unknown
  }

  func refresh(modelID: String) async {
    guard let package = LocalModelPackageCatalog.package(id: modelID) else { return }
    states[modelID] = .checking
    states[modelID] = await resolvedState(for: package)
  }

  func refreshAll() async {
    for package in LocalModelPackageCatalog.packages {
      states[package.id] = .checking
    }
    for package in LocalModelPackageCatalog.packages {
      states[package.id] = await resolvedState(for: package)
    }
  }

  func download(modelID: String) async {
    guard let package = LocalModelPackageCatalog.package(id: modelID) else { return }
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
      states[modelID] = await resolvedState(for: package)
    } catch {
      states[modelID] = .failed(error.localizedDescription)
    }
  }

  func delete(modelID: String) async {
    guard let package = LocalModelPackageCatalog.package(id: modelID) else { return }
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
    for package: LocalModelPackageDefinition
  ) async -> LocalModelPackageState {
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

  private func assetsRequiredByOtherInstalledPackages(
    excluding modelID: String
  ) async -> Set<LocalModelAsset> {
    var retained: Set<LocalModelAsset> = []
    for package in LocalModelPackageCatalog.packages where package.id != modelID {
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
