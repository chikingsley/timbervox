import Foundation
import Observation

@MainActor
@Observable
final class ModeModelPreferenceStore {
  static let shared = ModeModelPreferenceStore()

  private static let favoriteIDsKey = "favoriteModeModelIDs"
  private let defaults: UserDefaults
  private(set) var favoriteModelIDs: Set<String>

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    favoriteModelIDs = Set(defaults.stringArray(forKey: Self.favoriteIDsKey) ?? [])
  }

  func isFavorite(_ modelID: String) -> Bool {
    favoriteModelIDs.contains(modelID)
  }

  func toggleFavorite(_ modelID: String) {
    if favoriteModelIDs.contains(modelID) {
      favoriteModelIDs.remove(modelID)
    } else {
      favoriteModelIDs.insert(modelID)
    }
    defaults.set(favoriteModelIDs.sorted(), forKey: Self.favoriteIDsKey)
  }
}
