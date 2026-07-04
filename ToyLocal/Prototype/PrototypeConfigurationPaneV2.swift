import SwiftUI

/// Consolidated configuration prototype.
/// Mock-only state; this is meant to compare the "one roof" settings layout
/// against the existing split General/Recording/Sound panes.
struct PrototypeConfigurationPaneV2: View {
  private static let microphones = ["Logitech BRIO (Default)", "MacBook Air Microphone", "RØDE Connect System"]
  private static let retentionOptions = ["Forever", "One year", "Six months", "One month", "One week"]

  @State private var route: ConfigurationRouteV2 = .main
  @State private var theme: ConfigurationThemeChoiceV2 = .automatic
  @State private var recordingSurface: RecordingSurfaceChoiceV2 = .cursor
  @State private var microphone = Self.microphones[0]
  @State private var inputGain = 0.62
  @State private var autoGain = true
  @State private var silenceRemoval = false
  @State private var dynamicNormalization = false
  @State private var autoUpdates = true
  @State private var launchOnLogin = false
  @State private var errorLogging = false
  @State private var retention = Self.retentionOptions[0]
  @State private var showDockIcon = false
  @State private var startOnMenuClick = false
  @State private var pasteResult = true
  @State private var streamFromCursor = true

  var body: some View {
    VStack(spacing: 0) {
      header
      ProtoPane {
        switch route {
        case .main:
          mainContent
        case .advanced:
          advancedContent
        }
      }
    }
  }

  private var header: some View {
    ProtoHeader(control: route == .main ? .sidebarToggle : .back { route = .main }) {
      HStack(spacing: 8) {
        Image(systemName: route == .main ? "gearshape" : "slider.horizontal.3")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
        Text(route == .main ? "Configuration" : "Advanced")
          .font(.system(size: 13, weight: .semibold))
      }
    } trailing: {
      HStack(spacing: 8) {
        if route == .main {
          ConfigurationHeaderPillV2(icon: "circle.lefthalf.filled", text: theme.label)
          ConfigurationHeaderPillV2(icon: recordingSurface.headerIcon, text: recordingSurface.label)
          Button {
            route = .advanced
          } label: {
            HStack(spacing: 5) {
              Text("Advanced")
              Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)
        } else {
          ConfigurationHeaderPillV2(icon: "exclamationmark.triangle", text: "Prototype")
        }
      }
    }
  }

  private var mainContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      appearanceSection
      inputSection
      shortcutsSection
      applicationSection
    }
  }

  private var advancedContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      advancedApplicationSection
      advancedTextInputSection
      advancedModelSection
    }
  }

  private var appearanceSection: some View {
    ConfigurationSectionV2(title: "Appearance") {
      VStack(spacing: 0) {
        ConfigurationVisualRowV2(title: "Theme") {
          ConfigurationVisualChoiceGroupV2 {
            ForEach(ConfigurationThemeChoiceV2.allCases) { option in
              ConfigurationVisualChoiceV2(label: option.label, selected: theme == option) {
                theme = option
              } preview: {
                ConfigurationThemeThumbnailV2(choice: option)
              }
            }
          }
        }

        ConfigurationDividerV2()

        ConfigurationVisualRowV2(
          title: "Recording window",
          subtitle: "Choose where dictation feedback lives while recording."
        ) {
          ConfigurationVisualChoiceGroupV2 {
            ForEach(RecordingSurfaceChoiceV2.allCases) { option in
              ConfigurationVisualChoiceV2(label: option.label, selected: recordingSurface == option) {
                recordingSurface = option
              } preview: {
                RecordingSurfacePreviewV2(choice: option, selected: recordingSurface == option)
              }
            }
          }
        }

        ConfigurationDividerV2()

        ConfigurationSurfaceDemoRowV2(choice: recordingSurface)
      }
    }
  }

  private var inputSection: some View {
    ConfigurationSectionV2(title: "Recording Input") {
      VStack(spacing: 0) {
        ConfigurationMenuRowV2(
          icon: "mic",
          title: "Microphone",
          detail: microphone,
          options: Self.microphones,
          selection: $microphone
        )
        ConfigurationDividerV2()
        HStack(spacing: 12) {
          Image(systemName: "waveform")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(width: 20)
          Text("Input level")
            .font(.system(size: 13, weight: .medium))
          Spacer()
          ConfigurationLevelMeterV2()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)

        ConfigurationDividerV2()

        HStack(spacing: 12) {
          Image(systemName: "slider.horizontal.3")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(width: 20)
          Text("Input gain")
            .font(.system(size: 13, weight: .medium))
          Spacer(minLength: 18)
          Slider(value: $inputGain, in: 0...1)
            .controlSize(.small)
            .frame(width: 220)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)

        ConfigurationDividerV2()
        ConfigurationToggleRowV2(icon: "speaker.wave.3", title: "Automatically increase microphone volume", isOn: $autoGain)
        ConfigurationDividerV2()
        ConfigurationToggleRowV2(icon: "forward.end", title: "Silence removal", isOn: $silenceRemoval)
        ConfigurationDividerV2()
        ConfigurationToggleRowV2(icon: "waveform.path.ecg", title: "Dynamic normalization", isOn: $dynamicNormalization)
      }
    }
  }

  private var shortcutsSection: some View {
    ConfigurationSectionV2(title: "Keyboard Shortcuts") {
      VStack(spacing: 0) {
        ConfigurationShortcutRowV2(title: "Toggle Recording", subtitle: "Starts and stops recordings", shortcut: "Alt+Space")
        ConfigurationDividerV2()
        ConfigurationShortcutRowV2(title: "Cancel Recording", subtitle: "Discards the active recording", shortcut: "Escape")
        ConfigurationDividerV2()
        ConfigurationShortcutRowV2(title: "Change mode", subtitle: "Activates the mode switcher", shortcut: "Alt+Shift+K")
        ConfigurationDividerV2()
        ConfigurationShortcutRowV2(title: "Push to Talk", subtitle: "Hold to record, release when done", shortcut: "Meta")
      }
    }
  }

  private var applicationSection: some View {
    ConfigurationSectionV2(title: "Application") {
      VStack(spacing: 0) {
        HStack(spacing: 12) {
          Image(systemName: "shippingbox")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(width: 20)
          Text("Update application")
            .font(.system(size: 13, weight: .medium))
          Spacer()
          Button("Check for Updates...") {}
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)

        ConfigurationDividerV2()
        ConfigurationToggleRowV2(icon: "arrow.clockwise", title: "Automatically check for updates", isOn: $autoUpdates)
        ConfigurationDividerV2()
        ConfigurationToggleRowV2(icon: "power", title: "Launch on login", isOn: $launchOnLogin)
        ConfigurationDividerV2()
        ConfigurationToggleRowV2(icon: "ladybug", title: "Error logging", isOn: $errorLogging)
        ConfigurationDividerV2()
        ConfigurationMenuRowV2(
          icon: "clock.arrow.circlepath",
          title: "Keep recordings for",
          detail: retention,
          options: Self.retentionOptions,
          selection: $retention
        )
      }
    }
  }

  private var advancedApplicationSection: some View {
    ConfigurationSectionV2(title: "Application") {
      VStack(spacing: 0) {
        ConfigurationToggleRowV2(icon: "dock.rectangle", title: "Show in Dock", isOn: $showDockIcon)
        ConfigurationDividerV2()
        ConfigurationToggleRowV2(icon: "menubar.arrow.up.rectangle", title: "Start recording on menubar click", isOn: $startOnMenuClick)
      }
    }
  }

  private var advancedTextInputSection: some View {
    ConfigurationSectionV2(title: "Text Input") {
      VStack(spacing: 0) {
        ConfigurationToggleRowV2(icon: "doc.on.clipboard", title: "Paste result text", isOn: $pasteResult)
        ConfigurationDividerV2()
        ConfigurationToggleRowV2(icon: "cursorarrow.rays", title: "Stream text from cursor", badge: "AI", isOn: $streamFromCursor)
      }
    }
  }

  private var advancedModelSection: some View {
    ConfigurationSectionV2(title: "Voice Model") {
      VStack(spacing: 0) {
        ConfigurationMenuRowV2(
          icon: "memorychip",
          title: "Voice model active duration",
          detail: "5 minutes",
          options: ["1 minute", "5 minutes", "15 minutes", "30 minutes", "Always"],
          selection: .constant("5 minutes")
        )
        ConfigurationDividerV2()
        HStack(spacing: 12) {
          Image(systemName: "folder")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(width: 20)
          Text("~/Documents/ToyLocal")
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer()
          Button("Change folder...") {}
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
      }
    }
  }
}

private enum ConfigurationRouteV2 {
  case main, advanced
}

private enum ConfigurationThemeChoiceV2: String, CaseIterable, Identifiable {
  case automatic, light, dark

  var id: String { rawValue }

  var label: String {
    switch self {
    case .automatic: "Auto"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var assetName: String {
    switch self {
    case .automatic: "appearance-auto@2x.png"
    case .light: "appearance-light@2x.png"
    case .dark: "appearance-dark@2x.png"
    }
  }
}

private enum RecordingSurfaceChoiceV2: String, CaseIterable, Identifiable {
  case classic, mini, notch, cursor, input, none

  var id: String { rawValue }

  var label: String {
    switch self {
    case .classic: "Classic"
    case .mini: "Mini"
    case .notch: "Notch"
    case .cursor: "Cursor"
    case .input: "Input"
    case .none: "None"
    }
  }

  var headerIcon: String {
    switch self {
    case .classic: "waveform"
    case .mini: "waveform.circle"
    case .notch: "macbook"
    case .cursor: "cursorarrow.rays"
    case .input: "text.cursor"
    case .none: "eye.slash"
    }
  }
}

private struct ConfigurationSectionV2<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.leading, 2)
      content
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }
  }
}

private struct ConfigurationVisualRowV2<Content: View>: View {
  let title: String
  var subtitle = ""
  @ViewBuilder var content: Content

  var body: some View {
    HStack(alignment: .top, spacing: 18) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      content
        .frame(maxWidth: 420, alignment: .trailing)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
  }
}

private struct ConfigurationVisualChoiceGroupV2<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      content
    }
  }
}

private struct ConfigurationVisualChoiceV2<Preview: View>: View {
  let label: String
  let selected: Bool
  let action: () -> Void
  @ViewBuilder var preview: Preview
  @State private var hovering = false

  var body: some View {
    VStack(spacing: 6) {
      Button(action: action) {
        preview
          .frame(width: 82, height: 58)
          .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .strokeBorder(selected ? Color.accentColor : Color.white.opacity(hovering ? 0.22 : 0.1), lineWidth: selected ? 1.4 : 1)
          )
          .contentShape(RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)
      .onHover { hovering = $0 }

      Text(label)
        .font(.system(size: 11, weight: selected ? .semibold : .medium))
        .foregroundStyle(selected ? .primary : .secondary)
    }
    .frame(width: 84)
  }
}

private struct ConfigurationThemeThumbnailV2: View {
  let choice: ConfigurationThemeChoiceV2

  var body: some View {
    if let image = choice.image {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: 82, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    } else {
      RoundedRectangle(cornerRadius: 10)
        .fill(.white.opacity(0.08))
        .overlay(Text(choice.label).font(.system(size: 11)))
    }
  }
}

private extension ConfigurationThemeChoiceV2 {
  var image: NSImage? {
    let fileURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent("ConfigurationAssets/\(assetName)")
    return NSImage(contentsOf: fileURL)
  }
}

private struct RecordingSurfacePreviewV2: View {
  let choice: RecordingSurfaceChoiceV2
  let selected: Bool

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10)
        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.72))

      switch choice {
      case .classic:
        Capsule()
          .fill(.black.opacity(0.55))
          .frame(width: 62, height: 26)
          .overlay(ConfigurationWaveformV2(color: selected ? .accentColor : .secondary, bars: 12, height: 17))
      case .mini:
        RoundedRectangle(cornerRadius: 9)
          .fill(.black.opacity(0.55))
          .frame(width: 35, height: 30)
          .overlay(ConfigurationWaveformV2(color: selected ? .accentColor : .secondary, bars: 5, height: 18))
      case .notch:
        VStack(spacing: 6) {
          Capsule()
            .fill(.black)
            .frame(width: 48, height: 14)
          Capsule()
            .fill(.black.opacity(0.58))
            .frame(width: 66, height: 22)
            .overlay(ConfigurationWaveformV2(color: selected ? .accentColor : .secondary, bars: 9, height: 13))
        }
      case .cursor:
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 5)
            .fill(.white.opacity(0.07))
            .frame(width: 58, height: 34)
            .overlay(alignment: .leading) {
              Rectangle().fill(.white.opacity(0.65)).frame(width: 1, height: 22).padding(.leading, 20)
            }
          Capsule()
            .fill(.black.opacity(0.72))
            .frame(width: 34, height: 18)
            .overlay(ConfigurationWaveformV2(color: selected ? .accentColor : .secondary, bars: 5, height: 10))
            .offset(x: 28, y: -10)
        }
      case .input:
        RoundedRectangle(cornerRadius: 7)
          .fill(.white.opacity(0.07))
          .frame(width: 62, height: 22)
          .overlay(alignment: .leading) {
            Capsule()
              .fill(.black.opacity(0.72))
              .frame(width: 25, height: 16)
              .overlay(ConfigurationWaveformV2(color: selected ? .accentColor : .secondary, bars: 4, height: 9))
              .padding(.leading, -3)
          }
      case .none:
        Image(systemName: "eye.slash")
          .font(.system(size: 20, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct ConfigurationSurfaceDemoRowV2: View {
  let choice: RecordingSurfaceChoiceV2

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Preview")
          .font(.system(size: 13, weight: .semibold))
        Text(description)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      ConfigurationLiveSurfacePreviewV2(choice: choice)
        .frame(width: 300, height: 146)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
  }

  private var description: String {
    switch choice {
    case .classic:
      "A stable top overlay with waveform and the current transcript line."
    case .mini:
      "Compact feedback when you only need recording state and level."
    case .notch:
      "A notch-adjacent surface for laptops, drawn as our own Dynamic Island-style variant."
    case .cursor:
      "A small waveform beside the insertion point, backed by Accessibility caret bounds in the real app."
    case .input:
      "Attached to the focused input field when caret bounds are unavailable but the element frame is known."
    case .none:
      "No recording window. Sounds and menu-bar state carry the feedback."
    }
  }
}

private struct ConfigurationLiveSurfacePreviewV2: View {
  let choice: RecordingSurfaceChoiceV2

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.black.opacity(0.18))
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          Circle().fill(.red.opacity(0.85)).frame(width: 7, height: 7)
          Circle().fill(.yellow.opacity(0.85)).frame(width: 7, height: 7)
          Circle().fill(.green.opacity(0.85)).frame(width: 7, height: 7)
        }
        RoundedRectangle(cornerRadius: 7)
          .fill(.white.opacity(0.08))
          .frame(height: 88)
          .overlay(previewOverlay)
      }
      .padding(12)
    }
  }

  @ViewBuilder private var previewOverlay: some View {
    switch choice {
    case .classic:
      VStack(spacing: 10) {
        Capsule()
          .fill(.black.opacity(0.76))
          .frame(width: 190, height: 32)
          .overlay(HStack(spacing: 10) {
            ConfigurationWaveformV2(color: .accentColor, bars: 12, height: 18)
            Text("turn that into a cleaner note")
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.primary)
              .lineLimit(1)
          })
        Spacer()
      }
      .padding(.top, 8)
    case .mini:
      VStack {
        HStack {
          Spacer()
          RoundedRectangle(cornerRadius: 11)
            .fill(.black.opacity(0.76))
            .frame(width: 46, height: 34)
            .overlay(ConfigurationWaveformV2(color: .accentColor, bars: 5, height: 18))
        }
        Spacer()
      }
      .padding(10)
    case .notch:
      VStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 12)
          .fill(.black)
          .frame(width: 76, height: 18)
        Capsule()
          .fill(.black.opacity(0.78))
          .frame(width: 168, height: 34)
          .overlay(HStack(spacing: 8) {
            ConfigurationWaveformV2(color: .accentColor, bars: 8, height: 16)
            Text("recording")
              .font(.system(size: 11, weight: .semibold))
          })
        Spacer()
      }
    case .cursor:
      ZStack(alignment: .topLeading) {
        Text("Write the summary here")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
          .padding(.top, 26)
          .padding(.leading, 46)
        Rectangle()
          .fill(.white.opacity(0.75))
          .frame(width: 1, height: 25)
          .padding(.top, 22)
          .padding(.leading, 74)
        Capsule()
          .fill(.black.opacity(0.82))
          .frame(width: 118, height: 26)
          .overlay(HStack(spacing: 7) {
            ConfigurationWaveformV2(color: .accentColor, bars: 5, height: 13)
            Text("capturing...")
              .font(.system(size: 10, weight: .semibold))
          })
          .padding(.top, 5)
          .padding(.leading, 84)
      }
    case .input:
      VStack(spacing: 0) {
        Spacer()
        RoundedRectangle(cornerRadius: 9)
          .fill(.black.opacity(0.28))
          .frame(width: 220, height: 32)
          .overlay(alignment: .leading) {
            Capsule()
              .fill(.black.opacity(0.82))
              .frame(width: 84, height: 24)
              .overlay(ConfigurationWaveformV2(color: .accentColor, bars: 7, height: 14))
              .offset(x: -8)
          }
        Spacer()
      }
    case .none:
      VStack(spacing: 8) {
        Image(systemName: "eye.slash")
          .font(.system(size: 20))
          .foregroundStyle(.secondary)
        Text("No overlay")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct ConfigurationWaveformV2: View {
  var color: Color
  var bars: Int
  var height: CGFloat

  var body: some View {
    TimelineView(.animation(minimumInterval: 0.12)) { context in
      let phase = context.date.timeIntervalSinceReferenceDate
      HStack(alignment: .center, spacing: 2) {
        ForEach(0..<bars, id: \.self) { index in
          let value = 0.35 + 0.65 * abs(sin(phase * 2.4 + Double(index) * 0.72))
          RoundedRectangle(cornerRadius: 1.5)
            .fill(color.opacity(0.75 + 0.25 * value))
            .frame(width: 3, height: max(4, height * value))
        }
      }
      .frame(height: height)
    }
  }
}

private struct ConfigurationLevelMeterV2: View {
  var body: some View {
    TimelineView(.animation(minimumInterval: 0.1)) { context in
      let phase = context.date.timeIntervalSinceReferenceDate
      let active = Int(12 + 5 * sin(phase * 1.8))
      HStack(spacing: 3) {
        ForEach(0..<22, id: \.self) { index in
          RoundedRectangle(cornerRadius: 1.5)
            .fill(index < active ? Color.green.opacity(0.82) : Color.white.opacity(0.13))
            .frame(width: 4, height: index == active + 1 ? 18 : 12)
        }
      }
      .frame(width: 142, height: 20)
    }
  }
}

private struct ConfigurationToggleRowV2: View {
  let icon: String
  let title: String
  var badge = ""
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .frame(width: 20)
      Text(title)
        .font(.system(size: 13, weight: .medium))
      if !badge.isEmpty {
        ProtoKbd(badge)
      }
      Spacer()
      Toggle("", isOn: $isOn)
        .toggleStyle(.switch)
        .controlSize(.small)
        .labelsHidden()
    }
    .padding(.horizontal, 14)
    .frame(height: 48)
  }
}

private struct ConfigurationMenuRowV2: View {
  let icon: String
  let title: String
  let detail: String
  let options: [String]
  @Binding var selection: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .frame(width: 20)
      Text(title)
        .font(.system(size: 13, weight: .medium))
      Spacer()
      Menu {
        ForEach(options, id: \.self) { option in
          Button {
            selection = option
          } label: {
            if option == selection {
              Label(option, systemImage: "checkmark")
            } else {
              Text(option)
            }
          }
        }
      } label: {
        HStack(spacing: 6) {
          Text(detail)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.middle)
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
      .frame(maxWidth: 210, alignment: .trailing)
    }
    .padding(.horizontal, 14)
    .frame(height: 48)
  }
}

private struct ConfigurationShortcutRowV2: View {
  let title: String
  let subtitle: String
  let shortcut: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "keyboard")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 13, weight: .medium))
        Text(subtitle)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      Spacer()
      ProtoKbd(shortcut)
    }
    .padding(.horizontal, 14)
    .frame(height: 54)
  }
}

private struct ConfigurationHeaderPillV2: View {
  let icon: String
  let text: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .semibold))
      Text(text)
        .font(.system(size: 12, weight: .semibold))
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, 9)
    .frame(height: 28)
    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct ConfigurationDividerV2: View {
  var body: some View {
    Rectangle()
      .fill(.white.opacity(0.08))
      .frame(height: 1)
      .padding(.horizontal, 14)
  }
}

#Preview("Configuration V2") {
  PrototypeConfigurationPaneV2()
    .frame(width: 660, height: 760)
    .background(PrototypeTheme.windowBackground)
}
