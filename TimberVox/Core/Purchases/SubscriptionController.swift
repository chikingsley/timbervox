import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionController {
  static let shared = SubscriptionController()

  private(set) var cloudAccessIsActive = false
  private(set) var cloudPrice = "$7.99 / month"
  private(set) var isConfigured = false
  private(set) var isLoading = false
  private(set) var lastError: String?
  private(set) var localProIsActive = false
  private(set) var localProPrice = "$19.99 once"

  private var cloudPackage: RevenueCat.Package?
  private var localProPackage: RevenueCat.Package?

  private init() {
    guard
      let apiKey = Bundle.main.object(
        forInfoDictionaryKey: "RevenueCatAPIKey"
      ) as? String,
      !apiKey.isEmpty
    else {
      lastError = "Purchases are not configured for this build."
      return
    }
    #if DEBUG
      Purchases.logLevel = .debug
    #endif
    Purchases.configure(
      withAPIKey: apiKey,
      appUserID: AccountlessIdentity.current.appUserID
    )
    isConfigured = true
  }

  func refresh() async {
    guard isConfigured, !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      async let offerings = Purchases.shared.offerings()
      async let customerInfo = Purchases.shared.customerInfo()
      let (resolvedOfferings, resolvedCustomerInfo) = try await (
        offerings,
        customerInfo
      )
      cloudPackage = resolvedOfferings.current?.monthly
      localProPackage = resolvedOfferings.current?.lifetime
      #if !DEBUG
        if let localizedPrice = cloudPackage?.storeProduct.localizedPriceString {
          cloudPrice = "\(localizedPrice) / month"
        }
        if let localizedPrice = localProPackage?.storeProduct.localizedPriceString {
          localProPrice = "\(localizedPrice) once"
        }
      #endif
      apply(resolvedCustomerInfo)
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
  }

  func purchaseCloudAccess() async {
    guard let cloudPackage else {
      lastError = "The Cloud Access product is unavailable."
      return
    }
    await purchase(cloudPackage)
  }

  func restorePurchases() async {
    guard isConfigured, !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      apply(try await Purchases.shared.restorePurchases())
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func purchase(_ package: RevenueCat.Package) async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let result = try await Purchases.shared.purchase(package: package)
      if !result.userCancelled {
        apply(result.customerInfo)
      }
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func apply(_ customerInfo: CustomerInfo) {
    let hasCloudAccess =
      customerInfo.entitlements["cloud_access"]?.isActive ?? false
    let hasLocalPro =
      customerInfo.entitlements["local_pro"]?.isActive ?? false

    cloudAccessIsActive = hasCloudAccess
    localProIsActive = hasLocalPro
  }
}
