import SwiftUI
import TimberVoxCore

struct ModeListRow: View {
  let mode: ModeDraft
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
              .fill(Theme.accentGreen)
              .frame(width: 7, height: 7)
          }
        }

        Spacer(minLength: 12)

        ProviderLogo(provider: mode.voiceModel.provider, size: 24)
        if mode.usesLanguageModel {
          ProviderLogo(provider: mode.languageModel.provider, size: 24)
        }
      }
      .padding(.horizontal, 16)
      .frame(height: 50)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(.primary.opacity(hovering ? 0.12 : 0.09))
      )
      .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

struct ModesTip: View {
  @State private var isDismissed = false

  var body: some View {
    if isDismissed {
      EmptyView()
    } else {
      tipContent
    }
  }

  private var tipContent: some View {
    HStack(spacing: 12) {
      Image(systemName: "lightbulb.fill")
        .font(.system(size: 20))
        .foregroundStyle(.white)
        .frame(width: 38, height: 38)
        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 9))
      VStack(alignment: .leading, spacing: 3) {
        Text("Auto-switch with activation")
          .font(.system(size: 13, weight: .semibold))
        Text("Link a mode to specific apps or websites so \(AppBrand.name) picks the right one automatically when you record.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      Button("Dismiss") {
        isDismissed = true
      }
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(.tertiary)
      .buttonStyle(.plain)
    }
    .padding(14)
    .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
    )
  }
}

struct ModesDetailTitle: View {
  let mode: ModeDraft
  @Binding var draft: String
  let isEditing: Bool
  let beginEditing: () -> Void
  let commit: () -> Void
  let cancel: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Spacer()
      Image(systemName: mode.leadingIcon)
        .font(.system(size: 18, weight: .semibold))
      if isEditing {
        TextField("Mode name", text: $draft)
          .textFieldStyle(.plain)
          .font(.system(size: 15, weight: .semibold))
          .frame(width: 170)
          .padding(.horizontal, 8)
          .frame(height: 28)
          .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
        IconButton(
          systemName: "checkmark",
          tileSize: 22,
          hitSize: 28,
          foreground: Theme.accentGreen,
          help: "Save mode name",
          action: commit
        )
        IconButton(
          systemName: "xmark",
          tileSize: 22,
          hitSize: 28,
          help: "Cancel rename",
          action: cancel
        )
      } else {
        Button(action: beginEditing) {
          Text(mode.name)
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      if mode.isActive {
        Circle()
          .fill(Theme.accentGreen)
          .frame(width: 7, height: 7)
      }
      Spacer()
    }
    .padding(.top, 4)
  }
}

struct ModesShortcutRow: View {
  private static let defaultKeys: [String] = []
  @State private var keys = defaultKeys

  var body: some View {
    SettingsRow(
      title: "Keyboard shortcut",
      subtitle: "Start a recording in this mode",
      height: 58
    ) {
      ShortcutRecorder(keys: $keys, defaultKeys: Self.defaultKeys)
    }
  }
}

struct ModesRealtimeRow: View {
  @Binding var isOn: Bool

  var body: some View {
    SettingsToggleRow(
      title: "Realtime",
      hint: "If enabled, supported models stream partial transcription while recording and use the realtime result when available.",
      isOn: $isOn
    )
  }
}

struct ModesValuePill: View {
  let text: String
  var icon: String?
  var provider: ProviderBrand?
  var width: CGFloat = 152

  var body: some View {
    HStack(spacing: 7) {
      if let provider {
        ProviderLogo(provider: provider, size: 18)
      } else if let icon {
        Image(systemName: icon)
          .font(.system(size: 11))
          .foregroundStyle(Theme.accentGreen)
      }
      Text(text)
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .frame(width: width, height: 30, alignment: .leading)
    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

#Preview("Modes realtime row") {
  @Previewable @State var enabled = false
  FloatingHost {
    SettingsCard {
      ModesRealtimeRow(isOn: $enabled)
    }
    .padding(24)
    .frame(width: 520)
    .background(Theme.windowBackground)
  }
}

struct ModesActionRow: View {
  let title: String
  var subtitle = ""
  let actionTitle: String

  var body: some View {
    SettingsRow(
      title: title,
      subtitle: subtitle,
      height: subtitle.isEmpty ? 50 : 58
    ) {
      ActionPill(title: actionTitle)
    }
  }
}
