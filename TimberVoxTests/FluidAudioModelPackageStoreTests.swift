import Foundation
import XCTest

@testable import TimberVox

@MainActor
final class FluidAudioModelPackageStoreTests: XCTestCase {
  func testDownloadedButUnverifiedPackageIsPrepared() async throws {
    let package = try XCTUnwrap(
      FluidAudioModelPackageCatalog.package(id: "local-hummingbird")
    )
    let backend = ModelAssetBackendMock(
      states: Dictionary(
        uniqueKeysWithValues: package.assets.map {
          ($0, .downloaded)
        }
      )
    )
    let store = FluidAudioModelPackageStore(backend: backend)

    await store.refresh(modelID: "local-hummingbird")
    XCTAssertEqual(store.state(for: "local-hummingbird"), .downloaded(unverified: 2))

    await store.download(modelID: "local-hummingbird")

    XCTAssertEqual(store.state(for: "local-hummingbird"), .ready)
    let prepareCount = await backend.totalPrepareCount()
    XCTAssertEqual(prepareCount, 2)
  }

  func testNaturalPreparationFailureProducesTerminalFailure() async throws {
    let package = try XCTUnwrap(
      FluidAudioModelPackageCatalog.package(id: "local-hummingbird")
    )
    let failingAsset = package.assets[1]
    let backend = ModelAssetBackendMock(failingAssets: [failingAsset])
    let store = FluidAudioModelPackageStore(backend: backend)

    await store.download(modelID: package.id)

    guard case .failed(let message) = store.state(for: package.id) else {
      return XCTFail("Expected a failed package state.")
    }
    XCTAssertTrue(message.contains("Simulated model preparation failure"))
    XCTAssertEqual(store.recentDownloadResults.count, 1)
  }

  func testConcurrentPackagesPrepareSharedAssetOnce() async {
    let backend = ModelAssetBackendMock(prepareDelay: .milliseconds(40))
    let store = FluidAudioModelPackageStore(backend: backend)

    async let nightingale: Void = store.download(modelID: "local-nightingale")
    async let songbird: Void = store.download(modelID: "local-songbird")
    _ = await (nightingale, songbird)

    XCTAssertEqual(store.state(for: "local-nightingale"), .ready)
    XCTAssertEqual(store.state(for: "local-songbird"), .ready)
    let sharedCount = await backend.prepareCount(for: .batch(.parakeetTdtV3))
    XCTAssertEqual(sharedCount, 1)
  }

  func testDeletingPackageRetainsAssetRequiredByAnotherInstalledPackage() async throws {
    let nightingale = try XCTUnwrap(
      FluidAudioModelPackageCatalog.package(id: "local-nightingale")
    )
    let songbird = try XCTUnwrap(
      FluidAudioModelPackageCatalog.package(id: "local-songbird")
    )
    let installedAssets = Set(nightingale.assets + songbird.assets)
    let backend = ModelAssetBackendMock(
      states: Dictionary(uniqueKeysWithValues: installedAssets.map { ($0, .verified) })
    )
    let store = FluidAudioModelPackageStore(backend: backend)

    await store.delete(modelID: nightingale.id)

    let deletedAssets = await backend.deletedAssets()
    XCTAssertFalse(deletedAssets.contains(.batch(.parakeetTdtV3)))
    XCTAssertTrue(deletedAssets.contains(.realtime(.nemotronEnglish1120, language: "en")))
  }

  func testPackageProgressUsesEstimatedByteWeights() throws {
    let hummingbird = try XCTUnwrap(
      FluidAudioModelPackageCatalog.package(id: "local-hummingbird")
    )
    let batchBytes = FluidAudioModelPackageCatalog.estimatedDownloadBytes(
      for: .batch(.parakeetTdtCtc110M)
    )
    let progress = FluidAudioModelPackageProgress(
      estimatedCompletedBytes: batchBytes,
      estimatedTotalBytes: hummingbird.estimatedDownloadBytes
    )

    XCTAssertEqual(hummingbird.estimatedDownloadBytes, 853_897_095)
    XCTAssertEqual(progress.fractionCompleted, Double(batchBytes) / 853_897_095, accuracy: 0.000_001)
    XCTAssertLessThan(progress.fractionCompleted, 0.5)
  }
}

private actor ModelAssetBackendMock: FluidAudioModelAssetManaging {
  enum MockError: LocalizedError {
    case preparationFailed

    var errorDescription: String? {
      "Simulated model preparation failure."
    }
  }

  private var assetStates: [FluidAudioModelAsset: FluidAudioModelAssetState]
  private var prepareCounts: [FluidAudioModelAsset: Int] = [:]
  private var deletions: Set<FluidAudioModelAsset> = []
  private let failingAssets: Set<FluidAudioModelAsset>
  private let prepareDelay: Duration

  init(
    states: [FluidAudioModelAsset: FluidAudioModelAssetState] = [:],
    failingAssets: Set<FluidAudioModelAsset> = [],
    prepareDelay: Duration = .zero
  ) {
    assetStates = states
    self.failingAssets = failingAssets
    self.prepareDelay = prepareDelay
  }

  func state(of asset: FluidAudioModelAsset) -> FluidAudioModelAssetState {
    assetStates[asset] ?? .missing
  }

  func installedBytes(of asset: FluidAudioModelAsset) -> Int64 {
    assetStates[asset] == .missing ? 0 : 1_024
  }

  func prepare(
    _ asset: FluidAudioModelAsset,
    progress: @Sendable @escaping (Double) -> Void
  ) async throws {
    prepareCounts[asset, default: 0] += 1
    progress(0.25)
    if prepareDelay > .zero {
      try await Task.sleep(for: prepareDelay)
    }
    if failingAssets.contains(asset) {
      throw MockError.preparationFailed
    }
    progress(0.75)
    assetStates[asset] = .verified
    progress(1)
  }

  func delete(_ asset: FluidAudioModelAsset) {
    deletions.insert(asset)
    assetStates[asset] = .missing
  }

  func totalPrepareCount() -> Int {
    prepareCounts.values.reduce(0, +)
  }

  func prepareCount(for asset: FluidAudioModelAsset) -> Int {
    prepareCounts[asset, default: 0]
  }

  func deletedAssets() -> Set<FluidAudioModelAsset> {
    deletions
  }
}
