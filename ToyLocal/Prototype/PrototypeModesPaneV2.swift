import SwiftUI

/// Minimal modes prototype based on the compact Superwhisper reference.
/// Separate from PrototypeModesPane so both versions can be compared.
struct PrototypeModesPaneV2: View {
  private enum Route {
    case list
    case detail
  }

  @State private var route: Route = .list
  @State private var selectedMode = PrototypeModeV2.modes[0]
  @State private var microphone = "Logitech BRIO (Default)"

  var body: some View {
    VStack(spacing: 0) {
      ProtoHeader {
        if route == .detail {
          Button {
            withAnimation(.easeInOut(duration: 0.18)) {
              route = .list
            }
          } label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.secondary)
              .frame(width: 24, height: 24)
          }
          .buttonStyle(.plain)
        } else {
          EmptyView()
        }
      } trailing: {
        microphoneMenu
      }

      ZStack(alignment: .top) {
        switch route {
        case .list:
          listPage
            .transition(.opacity.combined(with: .move(edge: .leading)))
        case .detail:
          detailPage
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
      }
      .animation(.easeInOut(duration: 0.18), value: route)
    }
  }

  private var microphoneMenu: some View {
    Menu {
      ForEach(["Logitech BRIO (Default)", "MacBook Air Microphone", "RØDE Connect System"], id: \.self) { device in
        Button {
          microphone = device
        } label: {
          if device == microphone {
            Label(device, systemImage: "checkmark")
          } else {
            Text(device)
          }
        }
      }
    } label: {
      HStack(spacing: 7) {
        Text(microphone)
          .font(.system(size: 12, weight: .semibold))
        Image(systemName: "headphones")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      .foregroundStyle(.primary)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  private var listPage: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 8) {
        Text("Modes")
          .font(.system(size: 13, weight: .semibold))
        ProtoInfoHint("Modes change the preset, models, activation, and post-processing used when you record.")
        Spacer()
        Button {} label: {
          Label("Create mode", systemImage: "plus")
            .font(.system(size: 12, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
      }

      VStack(spacing: 10) {
        ForEach(PrototypeModeV2.modes) { mode in
          PrototypeModeRowV2(mode: mode) {
            selectedMode = mode
            withAnimation(.easeInOut(duration: 0.18)) {
              route = .detail
            }
          }
        }
      }

      Spacer()

      PrototypeModesV2Tip()
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
    .padding(.bottom, 18)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var detailPage: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 9) {
        Image(systemName: selectedMode.leadingIcon)
          .font(.system(size: 18, weight: .semibold))
          .frame(width: 28)
        Text(selectedMode.name)
          .font(.system(size: 15, weight: .semibold))
        if selectedMode.isActive {
          Circle()
            .fill(activeGreenV2)
            .frame(width: 7, height: 7)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 4)

      PrototypeModesV2Card {
        PrototypeModesV2PickerRow(title: "Preset", value: selectedMode.preset)
      }

      PrototypeModesV2Card {
        VStack(spacing: 0) {
          PrototypeModesV2PickerRow(title: "Language", value: "Automatic")
          PrototypeModesV2Divider()
          PrototypeModesV2PickerRow(title: "Voice Model", value: selectedMode.voiceModel, icon: "waveform")
          PrototypeModesV2Divider()
          PrototypeModesV2ToggleRow(title: "Realtime", isOn: selectedMode.realtime)
        }
      }

      PrototypeModesV2Card {
        VStack(spacing: 0) {
          PrototypeModesV2ActionRow(title: "Activate for apps", actionTitle: "Add apps and sites")
          PrototypeModesV2Divider()
          PrototypeModesV2ActionRow(title: "Keyboard shortcut", subtitle: "Start a recording in this mode", actionTitle: "Record shortcut")
        }
      }

      Button {} label: {
        HStack(spacing: 5) {
          Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .bold))
          Text("Advanced settings")
            .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.primary)
      }
      .buttonStyle(.plain)

      Spacer()
    }
    .padding(.horizontal, 24)
    .padding(.top, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

private let activeGreenV2 = Color(red: 0.49, green: 1.0, blue: 0.35)

private struct PrototypeModeV2: Identifiable, Equatable {
  let id: String
  let name: String
  let preset: String
  let leadingIcon: String
  let voiceModel: String
  let textModelIcon: String?
  let realtime: Bool
  let isActive: Bool

  static let modes: [PrototypeModeV2] = [
    PrototypeModeV2(
      id: "default",
      name: "Default",
      preset: "Voice to text",
      leadingIcon: "bubble.left.fill",
      voiceModel: "Parakeet M...",
      textModelIcon: nil,
      realtime: true,
      isActive: true
    ),
    PrototypeModeV2(
      id: "voice-to-text",
      name: "Voice to text",
      preset: "Voice to text",
      leadingIcon: "mic.fill",
      voiceModel: "Parakeet M...",
      textModelIcon: nil,
      realtime: false,
      isActive: false
    ),
    PrototypeModeV2(
      id: "email",
      name: "Email",
      preset: "Mail",
      leadingIcon: "envelope.fill",
      voiceModel: "Scribe",
      textModelIcon: "text.bubble.fill",
      realtime: false,
      isActive: false
    ),
    PrototypeModeV2(
      id: "meeting",
      name: "Meeting notes",
      preset: "Meeting Summary",
      leadingIcon: "person.2.fill",
      voiceModel: "Scribe",
      textModelIcon: "sparkles",
      realtime: false,
      isActive: false
    ),
  ]
}

private struct PrototypeModeRowV2: View {
  let mode: PrototypeModeV2
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: mode.leadingIcon)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
          .frame(width: 18)

        HStack(spacing: 7) {
          Text(mode.name)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
          if mode.isActive {
            Circle()
              .fill(activeGreenV2)
              .frame(width: 7, height: 7)
          }
        }

        Spacer(minLength: 12)

        PrototypeModelBadgeV2(systemImage: "lock.fill", tint: .secondary)
        PrototypeModelBadgeV2(systemImage: "waveform", tint: activeGreenV2)
        if let textModelIcon = mode.textModelIcon {
          PrototypeModelBadgeV2(systemImage: textModelIcon, tint: Color(red: 0.52, green: 0.72, blue: 1.0))
        }
      }
      .padding(.horizontal, 16)
      .frame(height: 50)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(.white.opacity(hovering ? 0.12 : 0.09))
      )
      .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

private struct PrototypeModelBadgeV2: View {
  let systemImage: String
  let tint: Color

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(tint)
      .frame(width: 25, height: 25)
      .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
      .overlay(
        RoundedRectangle(cornerRadius: 7)
          .strokeBorder(.white.opacity(0.12), lineWidth: 1)
      )
  }
}

private struct PrototypeModesV2Tip: View {
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "lightbulb.fill")
        .font(.system(size: 20))
        .foregroundStyle(.white)
        .frame(width: 38, height: 38)
        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 9))
      VStack(alignment: .leading, spacing: 3) {
        Text("Auto-switch with activation")
          .font(.system(size: 13, weight: .semibold))
        Text("Link a mode to specific apps or websites so ToyLocal picks the right one automatically when you record.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      Button("Dismiss") {}
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.tertiary)
        .buttonStyle(.plain)
    }
    .padding(14)
    .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
    )
  }
}

private struct PrototypeModesV2Card<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
  }
}

private struct PrototypeModesV2Divider: View {
  var body: some View {
    Rectangle()
      .fill(.white.opacity(0.1))
      .frame(height: 1)
      .padding(.horizontal, 16)
  }
}

private struct PrototypeModesV2PickerRow: View {
  let title: String
  let value: String
  var icon: String?

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
      Spacer()
      HStack(spacing: 7) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: 11))
            .foregroundStyle(activeGreenV2)
        }
        Text(value)
          .font(.system(size: 12, weight: .semibold))
          .lineLimit(1)
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 10)
      .frame(height: 30)
      .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
    .padding(.horizontal, 16)
    .frame(height: 50)
  }
}

private struct PrototypeModesV2ToggleRow: View {
  let title: String
  let isOn: Bool

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
      Spacer()
      Toggle("", isOn: .constant(isOn))
        .toggleStyle(.switch)
        .controlSize(.small)
        .labelsHidden()
    }
    .padding(.horizontal, 16)
    .frame(height: 50)
  }
}

private struct PrototypeModesV2ActionRow: View {
  let title: String
  var subtitle = ""
  let actionTitle: String

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      Button(actionTitle) {}
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .frame(height: subtitle.isEmpty ? 50 : 58)
  }
}

#Preview("Modes V2") {
  PrototypeModesPaneV2()
    .frame(width: 580, height: 680)
    .background(PrototypeTheme.windowBackground)
}
