import TimberVoxCore
import SwiftUI

struct SoundPane: View {
  private static let recordingAudioOptions = RecordingAudioBehavior.allCases.map {
    MenuOption(value: $0, label: $0.displayName)
  }
  private static let soundEffectStyles: [SoundEffectsStyle] = [.standard, .classic, .off]

  @Bindable var store: SettingsStore

  init(store: SettingsStore) {
    self.store = store
  }

  var body: some View {
    VStack(spacing: SoundPaneMetrics.stackSpacing) {
      Header {
        microphoneMenu
      }

      Pane {
        recordingSection
        soundEffectsSection
      }
    }
  }

  private var microphoneMenu: some View {
    HeaderMicrophoneMenu(store: store)
  }

  private var recordingSection: some View {
    PaneSection(title: "Recording") {
      SettingsCard {
        SettingsToggleRow(
          title: "Automatically increase microphone volume",
          hint: "Sets microphone input volume to max when starting a recording. Only works if using system default device.",
          isOn: $store.timberVoxSettings.autoIncreaseMicrophoneVolume
        )
        SettingsToggleRow(
          title: "Super fast mode",
          hint:
            "Keeps the microphone engine warm so recordings start instantly, and prepends a short pre-roll so the first "
            + "word is never clipped. macOS keeps showing the microphone indicator while the engine is armed.",
          isOn: Binding(
            get: { store.timberVoxSettings.superFastModeEnabled },
            set: { enabled in
              store.timberVoxSettings.superFastModeEnabled = enabled
              store.warmUpRecorderForCaptureModeChange()
            }
          )
        )
        playbackRow

      }
    }
  }

  private var soundEffectsSection: some View {
    PaneSection(title: "Sound Effects") {
      SettingsCard {
        soundEffectsRow
        volumeRow

      }
    }
  }

  private var playbackRow: some View {
    SettingsRow(
      title: "Playback when recording",
      hint: "Default playback behavior during recording. Individual modes can override this setting."
    ) {
      OptionMenu(
        selection: $store.timberVoxSettings.recordingAudioBehavior,
        options: Self.recordingAudioOptions
      )
    }
  }

  private var soundEffectsRow: some View {
    SettingsRow(title: "Sound effects") {
      Picker(
        "",
        selection: Binding(
          get: { store.timberVoxSettings.soundEffectsStyle },
          set: { store.setSoundEffectsStyle($0) }
        )
      ) {
        ForEach(Self.soundEffectStyles, id: \.self) { style in
          Text(style.displayName).tag(style)
        }
      }
      .pickerStyle(.segmented)
      .controlSize(.large)
      .frame(width: SoundPaneMetrics.soundStyleWidth)
    }
  }

  private var volumeRow: some View {
    SettingsRow(title: "Volume") {
      HStack(spacing: SoundPaneMetrics.volumeIconSpacing) {
        Image(systemName: "speaker.fill")
          .font(.system(size: SoundPaneMetrics.volumeIconSize))
          .foregroundStyle(.secondary)
        Slider(
          value: $store.timberVoxSettings.soundEffectsVolume,
          in: SoundPaneMetrics.minimumVolume...SoundPaneMetrics.maximumVolume
        ) { editing in
          if !editing {
            store.playSoundEffectsSample()
          }
        }
        .controlSize(.small)
        .frame(width: SoundPaneMetrics.volumeSliderWidth)
        Image(systemName: "speaker.wave.2.fill")
          .font(.system(size: SoundPaneMetrics.volumeIconSize))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private enum SoundPaneMetrics {
  static let stackSpacing: CGFloat = 0
  static let minimumVolume = 0.0
  static let maximumVolume = 1.0
  static let soundStyleWidth: CGFloat = 210
  static let volumeIconSpacing: CGFloat = 8
  static let volumeIconSize: CGFloat = 11
  static let volumeSliderWidth: CGFloat = 220
  static let previewWidth: CGFloat = 580
  static let previewHeight: CGFloat = 452
}

#Preview("Sound") {
  @Previewable @State var store = AppPreviewState.makeStore()
  FloatingHost {
    SoundPane(store: store.settings)
      .frame(width: SoundPaneMetrics.previewWidth, height: SoundPaneMetrics.previewHeight)
      .background(Theme.windowBackground)
  }
}
