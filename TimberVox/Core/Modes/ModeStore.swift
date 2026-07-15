import Foundation
import Observation

@MainActor
@Observable
final class ModeStore {
  static let shared = ModeStore()

  private static let modesKey = "dictationModes"
  private static let activeModeIDKey = "activeDictationModeID"

  private let defaults: UserDefaults

  var modes: [DictationMode] {
    didSet { saveModes() }
  }

  var activeModeID: String {
    didSet { defaults.set(activeModeID, forKey: Self.activeModeIDKey) }
  }

  var activeMode: DictationMode {
    modes.first { $0.id == activeModeID } ?? modes.first ?? .defaultMode(defaults: defaults)
  }

  func mode(forSourceApplicationBundleIdentifier bundleIdentifier: String?) -> DictationMode {
    guard let bundleIdentifier else { return activeMode }
    return modes.first { $0.activationBundleIdentifiers.contains(bundleIdentifier) } ?? activeMode
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let loadedModes: [DictationMode]
    if let data = defaults.data(forKey: Self.modesKey),
      let decoded = try? JSONDecoder().decode([DictationMode].self, from: data),
      !decoded.isEmpty
    {
      loadedModes = decoded
    } else {
      loadedModes = [.defaultMode(defaults: defaults)]
    }
    let storedActiveID = defaults.string(forKey: Self.activeModeIDKey)
    let resolvedID =
      storedActiveID.flatMap { candidate in
        loadedModes.contains { $0.id == candidate } ? candidate : nil
      } ?? loadedModes.first?.id ?? "default"
    modes = loadedModes
    activeModeID = resolvedID
  }

  func mode(id: String) -> DictationMode? {
    modes.first { $0.id == id }
  }

  @discardableResult
  func addMode(templateID: String? = nil) -> String {
    let template = templateID.flatMap(mode(id:)) ?? activeMode
    let newID = UUID().uuidString
    let newMode = DictationMode(
      id: newID,
      name: template.textTransformPreset.label,
      activationBundleIdentifiers: [],
      audioModelID: template.audioModelID,
      languageCode: template.languageCode,
      realtimeEnabled: template.realtimeEnabled,
      diarizationEnabled: template.diarizationEnabled,
      includesSystemAudio: template.includesSystemAudio,
      playbackPolicy: template.playbackPolicy,
      textTransformPreset: template.textTransformPreset,
      textTransformModelID: template.textTransformModelID,
      customTextTransformInstructions: template.customTextTransformInstructions,
      textTransformContextOptions: template.textTransformContextOptions
    )
    modes.append(newMode)
    return newID
  }

  @discardableResult
  func duplicateMode(id: String) -> String {
    let template = mode(id: id) ?? activeMode
    let newID = UUID().uuidString
    let duplicate = DictationMode(
      id: newID,
      name: "\(template.name) Copy",
      nameIsCustomized: true,
      iconSystemName: template.iconSystemName,
      activationBundleIdentifiers: template.activationBundleIdentifiers,
      audioModelID: template.audioModelID,
      languageCode: template.languageCode,
      realtimeEnabled: template.realtimeEnabled,
      diarizationEnabled: template.diarizationEnabled,
      includesSystemAudio: template.includesSystemAudio,
      playbackPolicy: template.playbackPolicy,
      textTransformPreset: template.textTransformPreset,
      textTransformModelID: template.textTransformModelID,
      customTextTransformInstructions: template.customTextTransformInstructions,
      textTransformContextOptions: template.textTransformContextOptions
    )
    modes.append(duplicate)
    return newID
  }

  func deleteActiveMode() {
    deleteMode(id: activeModeID)
  }

  func deleteMode(id: String) {
    guard modes.count > 1 else { return }
    let removedActiveMode = id == activeModeID
    modes.removeAll { $0.id == id }
    if removedActiveMode {
      activeModeID = modes.first?.id ?? "default"
    }
  }

  func updateActive(_ update: (inout DictationMode) -> Void) {
    updateMode(id: activeModeID, update)
  }

  func updateMode(id: String, _ update: (inout DictationMode) -> Void) {
    guard let index = modes.firstIndex(where: { $0.id == id }) else { return }
    update(&modes[index])
  }

  func ensureMode(_ mode: DictationMode) {
    guard self.mode(id: mode.id) == nil else { return }
    modes.append(mode)
  }

  @discardableResult
  func importMode(_ importedMode: DictationMode) -> String {
    var mode = importedMode
    mode.id = UUID().uuidString
    mode.name = availableImportedName(mode.name)
    mode.nameIsCustomized = true
    modes.append(mode)
    return mode.id
  }

  private func availableImportedName(_ proposedName: String) -> String {
    let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
    let base = trimmed.isEmpty ? "Imported Mode" : trimmed
    let existingNames = Set(modes.map { $0.name.localizedLowercase })
    guard existingNames.contains(base.localizedLowercase) else { return base }
    var suffix = 2
    while existingNames.contains("\(base) \(suffix)".localizedLowercase) {
      suffix += 1
    }
    return "\(base) \(suffix)"
  }

  private func saveModes() {
    guard let data = try? JSONEncoder().encode(modes) else { return }
    defaults.set(data, forKey: Self.modesKey)
  }
}
