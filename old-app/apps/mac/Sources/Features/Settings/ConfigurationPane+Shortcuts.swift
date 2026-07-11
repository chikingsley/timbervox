import SwiftUI

extension ConfigurationPane {
  var shortcutsSection: some View {
    PaneSection(title: "Keyboard Shortcuts") {
      SettingsCard {
        shortcutRow(
          .pushToTalk,
          icon: "hand.tap",
          title: "Push to Talk",
          subtitle: "Hold to record, release when done"
        )
        shortcutRow(
          .pasteLastTranscript,
          icon: "doc.on.clipboard",
          title: "Paste Last Transcript",
          subtitle: "Pastes the most recent transcript"
        )
      }
    }
  }

  var hotMicSection: some View {
    HotMicSettingsSection(store: store)
  }

  func shortcutRow(
    _ recorder: ShortcutSlot,
    icon: String,
    title: String,
    subtitle: String
  ) -> some View {
    SettingsRow(icon: icon, title: title, subtitle: subtitle, height: 54) {
      shortcutRecorder(recorder)
    }
  }

  @ViewBuilder
  func shortcutRecorder(_ recorder: ShortcutSlot) -> some View {
    switch recorder {
    case .pushToTalk:
      ShortcutRecorder(
        keys: Binding(get: { store.recordingHotKeyKeys }, set: { _ in }),
        defaultKeys: store.defaultRecordingHotKeyKeys,
        isRecording: Binding(
          get: { store.isSettingHotKey },
          set: { $0 ? store.beginRecordingHotKeyCapture() : store.cancelShortcutCapture() }
        ),
        onBeginRecording: store.beginRecordingHotKeyCapture,
        onCancelRecording: store.cancelShortcutCapture,
        onReset: store.resetRecordingHotKey
      )
    case .pasteLastTranscript:
      ShortcutRecorder(
        keys: Binding(get: { store.pasteLastTranscriptHotKeyKeys }, set: { _ in }),
        isRecording: Binding(
          get: { store.isSettingPasteLastTranscriptHotkey },
          set: { $0 ? store.beginPasteLastTranscriptHotkeyCapture() : store.cancelShortcutCapture() }
        ),
        onBeginRecording: store.beginPasteLastTranscriptHotkeyCapture,
        onCancelRecording: store.cancelShortcutCapture,
        onClear: store.clearPasteLastTranscriptHotkey
      )
    case .hotMicPaste:
      ShortcutRecorder(
        keys: Binding(get: { store.alwaysOnPasteHotKeyKeys }, set: { _ in }),
        defaultKeys: store.defaultAlwaysOnPasteHotKeyKeys,
        isRecording: Binding(
          get: { store.isSettingAlwaysOnPasteHotkey },
          set: { $0 ? store.beginAlwaysOnPasteHotkeyCapture() : store.cancelShortcutCapture() }
        ),
        onBeginRecording: store.beginAlwaysOnPasteHotkeyCapture,
        onCancelRecording: store.cancelShortcutCapture,
        onReset: store.resetAlwaysOnPasteHotkey
      )
    case .hotMicDump:
      ShortcutRecorder(
        keys: Binding(get: { store.alwaysOnDumpHotKeyKeys }, set: { _ in }),
        isRecording: Binding(
          get: { store.isSettingAlwaysOnDumpHotkey },
          set: { $0 ? store.beginAlwaysOnDumpHotkeyCapture() : store.cancelShortcutCapture() }
        ),
        onBeginRecording: store.beginAlwaysOnDumpHotkeyCapture,
        onCancelRecording: store.cancelShortcutCapture,
        onClear: store.clearAlwaysOnDumpHotkey
      )
    }
  }
}

private struct HotMicSettingsSection: View {
  @Bindable var store: SettingsStore

  var body: some View {
    PaneSection(title: "Hot Mic") {
      HStack(alignment: .top, spacing: HotMicSettingsMetrics.tileSpacing) {
        HotMicCommandTile(
          icon: "power",
          title: "Start / Stop",
          subtitle: "Turn Hot Mic listening completely on or off.",
          tint: Theme.accentBlue
        ) {
          Toggle("Hot Mic", isOn: $store.timberVoxSettings.alwaysOnEnabled)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }

        HotMicCommandTile(
          icon: "text.insert",
          title: "Paste",
          subtitle: "Paste what Hot Mic heard recently.",
          tint: Color(hex: Shadcn.green500)
        ) {
          pasteRecorder
        }

        HotMicCommandTile(
          icon: "arrow.down.to.line",
          title: "Dump",
          subtitle: "Clear what Hot Mic heard so you can start fresh.",
          tint: Color(hex: Shadcn.orange400)
        ) {
          dumpRecorder
        }
      }
    }
  }

  private var pasteRecorder: some View {
    ShortcutRecorder(
      keys: Binding(get: { store.alwaysOnPasteHotKeyKeys }, set: { _ in }),
      defaultKeys: store.defaultAlwaysOnPasteHotKeyKeys,
      isRecording: Binding(
        get: { store.isSettingAlwaysOnPasteHotkey },
        set: { $0 ? store.beginAlwaysOnPasteHotkeyCapture() : store.cancelShortcutCapture() }
      ),
      onBeginRecording: store.beginAlwaysOnPasteHotkeyCapture,
      onCancelRecording: store.cancelShortcutCapture,
      onReset: store.resetAlwaysOnPasteHotkey
    )
  }

  private var dumpRecorder: some View {
    ShortcutRecorder(
      keys: Binding(get: { store.alwaysOnDumpHotKeyKeys }, set: { _ in }),
      isRecording: Binding(
        get: { store.isSettingAlwaysOnDumpHotkey },
        set: { $0 ? store.beginAlwaysOnDumpHotkeyCapture() : store.cancelShortcutCapture() }
      ),
      onBeginRecording: store.beginAlwaysOnDumpHotkeyCapture,
      onCancelRecording: store.cancelShortcutCapture,
      onClear: store.clearAlwaysOnDumpHotkey
    )
  }
}

private struct HotMicCommandTile<Control: View>: View {
  let icon: String
  let title: String
  let subtitle: String
  let tint: Color
  @ViewBuilder var control: Control
  @State private var hovering = false

  var body: some View {
    VStack(alignment: .leading, spacing: HotMicSettingsMetrics.tileStackSpacing) {
      HStack(spacing: HotMicSettingsMetrics.iconSpacing) {
        Image(systemName: icon)
          .font(.system(size: HotMicSettingsMetrics.iconFontSize, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: HotMicSettingsMetrics.iconFrameSize, height: HotMicSettingsMetrics.iconFrameSize)
          .background(
            tint.opacity(HotMicSettingsMetrics.iconBackgroundOpacity),
            in: RoundedRectangle(cornerRadius: HotMicSettingsMetrics.iconCornerRadius)
          )
        Text(title)
          .font(.system(size: HotMicSettingsMetrics.titleFontSize, weight: .semibold))
          .lineLimit(HotMicSettingsMetrics.singleLineLimit)
      }

      Text(subtitle)
        .font(.system(size: HotMicSettingsMetrics.subtitleFontSize))
        .foregroundStyle(.secondary)
        .lineLimit(HotMicSettingsMetrics.subtitleLineLimit)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: HotMicSettingsMetrics.controlSpacerMinLength)

      HStack {
        Spacer(minLength: HotMicSettingsMetrics.controlHorizontalSpacing)
        control
        Spacer(minLength: HotMicSettingsMetrics.controlHorizontalSpacing)
      }
    }
    .padding(HotMicSettingsMetrics.tilePadding)
    .frame(maxWidth: .infinity, minHeight: HotMicSettingsMetrics.tileMinHeight, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: HotMicSettingsMetrics.tileCornerRadius)
        .fill(Theme.cardSurface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: HotMicSettingsMetrics.tileCornerRadius)
        .strokeBorder(
          tint.opacity(hovering ? HotMicSettingsMetrics.tileHoverStrokeOpacity : HotMicSettingsMetrics.tileStrokeOpacity),
          lineWidth: HotMicSettingsMetrics.tileStrokeWidth
        )
    )
    .shadow(
      color: Theme.cardShadow,
      radius: hovering ? HotMicSettingsMetrics.tileHoverShadowRadius : Theme.cardShadowRadius,
      y: Theme.cardShadowY
    )
    .onHover { hovering = $0 }
  }
}

private enum HotMicSettingsMetrics {
  static let tileSpacing: CGFloat = 10
  static let tileStackSpacing: CGFloat = 9
  static let iconSpacing: CGFloat = 7
  static let iconFontSize: CGFloat = 12
  static let iconFrameSize: CGFloat = 22
  static let iconCornerRadius: CGFloat = 6
  static let iconBackgroundOpacity = 0.14
  static let titleFontSize: CGFloat = 13
  static let singleLineLimit = 1
  static let subtitleFontSize: CGFloat = 11
  static let subtitleLineLimit = 3
  static let controlSpacerMinLength: CGFloat = 4
  static let controlHorizontalSpacing: CGFloat = 0
  static let tilePadding: CGFloat = 10
  static let tileMinHeight: CGFloat = 128
  static let tileCornerRadius: CGFloat = 10
  static let tileHoverStrokeOpacity = 0.32
  static let tileStrokeOpacity = 0.18
  static let tileStrokeWidth: CGFloat = 1
  static let tileHoverShadowRadius: CGFloat = 15
  static let previewWidth: CGFloat = 660
  static let previewHeight: CGFloat = 260
}

#Preview("Hot Mic Settings") {
  @Previewable @State var store = AppPreviewState.makeStore()
  FloatingHost {
    Pane {
      HotMicSettingsSection(store: store.settings)
    }
    .frame(width: HotMicSettingsMetrics.previewWidth, height: HotMicSettingsMetrics.previewHeight)
    .background(Theme.windowBackground)
  }
}
