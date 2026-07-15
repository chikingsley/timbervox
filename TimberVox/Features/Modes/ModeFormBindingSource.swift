import SwiftUI

@MainActor
struct ModeFormBindingSource {
  let modeID: String
  let modeStore: ModeStore
  let transcriptionCatalog: TranscriptionModelCatalogStore

  func optionalPreset(_ mode: DictationMode) -> Binding<ModeTextTransformPreset?> {
    Binding(
      get: { modeStore.mode(id: modeID)?.textTransformPreset ?? mode.textTransformPreset },
      set: { preset in
        guard let preset else { return }
        updateMode {
          let previousPreset = $0.textTransformPreset
          $0.textTransformPreset = preset
          if preset.allowsContextSelection, previousPreset != .custom {
            $0.textTransformContextOptions = .none
          } else if preset.usesAllAvailableContext {
            $0.textTransformContextOptions = .allAvailable
          }
          if preset == .custom,
            $0.customTextTransformInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          {
            $0.customTextTransformInstructions = TextTransformPreset.defaultCustomInstructions
          }
          if !$0.nameIsCustomized {
            $0.name = preset.referenceLabel
          }
        }
      }
    )
  }

  func optionalLanguage(_ mode: DictationMode) -> Binding<String?> {
    Binding(
      get: { modeStore.mode(id: modeID)?.languageCode ?? "" },
      set: { value in
        updateMode {
          guard let value, !value.isEmpty else {
            $0.languageCode = nil
            return
          }
          $0.languageCode = value
        }
      }
    )
  }

  func optionalAudioModelID(_ mode: DictationMode) -> Binding<String?> {
    Binding(
      get: { modeStore.mode(id: modeID)?.audioModelID ?? mode.audioModelID },
      set: { value in
        guard let value else { return }
        updateMode { $0.audioModelID = value }
      }
    )
  }

  func optionalLanguageModelID(_ mode: DictationMode) -> Binding<String?> {
    Binding(
      get: { modeStore.mode(id: modeID)?.textTransformModelID ?? mode.textTransformModelID },
      set: { value in
        guard let value else { return }
        updateMode { $0.textTransformModelID = value }
      }
    )
  }

  func optionalPlaybackPolicy(_ mode: DictationMode) -> Binding<PlaybackPolicy?> {
    Binding(
      get: { modeStore.mode(id: modeID)?.playbackPolicy ?? mode.playbackPolicy },
      set: { value in
        guard let value else { return }
        updateMode { $0.playbackPolicy = value }
      }
    )
  }

  func modeBinding<Value: Equatable>(
    _ keyPath: WritableKeyPath<DictationMode, Value>,
    fallback: Value
  ) -> Binding<Value> {
    Binding {
      modeStore.mode(id: modeID)?[keyPath: keyPath] ?? fallback
    } set: { value in
      updateMode { $0[keyPath: keyPath] = value }
    }
  }

  func contextOptionBinding(
    _ keyPath: WritableKeyPath<DictationContextOptions, Bool>,
    mode: DictationMode
  ) -> Binding<Bool> {
    Binding {
      let options =
        modeStore.mode(id: modeID)?.textTransformContextOptions
        ?? mode.textTransformContextOptions
      return options[keyPath: keyPath]
    } set: { value in
      updateMode { $0.textTransformContextOptions[keyPath: keyPath] = value }
    }
  }

  private func updateMode(_ update: (inout DictationMode) -> Void) {
    modeStore.updateMode(id: modeID, update)
    guard let current = modeStore.mode(id: modeID) else { return }
    let normalized = transcriptionCatalog.normalized(current)
    guard normalized != current else { return }
    modeStore.updateMode(id: modeID) { $0 = normalized }
  }
}
