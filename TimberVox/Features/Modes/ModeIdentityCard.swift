import SwiftUI

struct ModeIdentityCard: View {
  @Binding var name: String
  @Binding var icon: String?
  let resolvedIcon: String
  let isActive: Bool
  let canDelete: Bool
  let onUse: () -> Void
  let onDuplicate: () -> Void
  let onDelete: () -> Void

  var body: some View {
    SCCard(size: .sm) {
      SCCardHeader {
        SCCardTitle("Mode")
        SCCardDescription("Choose how this mode appears and whether it is currently in use.")
        SCCardAction { actions }
      }

      SCCardContent {
        HStack(alignment: .bottom, spacing: AppSpacing.md) {
          SCField {
            SCFieldLabel("Icon")
            SCCombobox(
              selection: $icon,
              options: iconOptions,
              placeholder: "Automatic",
              searchPlaceholder: "Search icons"
            )
            .frame(width: 184)
          }

          SCField {
            SCFieldLabel("Name")
            SCInput("Mode name", text: $name, icon: resolvedIcon)
          }
        }
      }

      SCCardFooter {
        if isActive {
          SCBadge {
            Label("Active mode", systemImage: "checkmark.circle.fill")
          }
        } else {
          Button("Use mode", systemImage: "checkmark.circle", action: onUse)
            .buttonStyle(.sc(.secondary, size: .sm))
        }
      }
    }
  }

  private var actions: some View {
    SCDropdownMenu {
      SCDropdownMenuTrigger {
        Image(systemName: "ellipsis")
          .frame(width: 24, height: 24)
      }
    } content: {
      SCDropdownMenuContent {
        SCDropdownMenuItem(action: onDuplicate) {
          Label("Duplicate", systemImage: "plus.square.on.square")
        }
        SCDropdownMenuItem(variant: .destructive, isDisabled: !canDelete, action: onDelete) {
          Label("Delete", systemImage: "trash")
        }
      }
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .accessibilityLabel("Mode actions")
  }

  private var iconOptions: [SCComboboxOption<String>] {
    [SCComboboxOption(value: "", label: "Automatic", keywords: [resolvedIcon])]
      + Self.iconChoices.map {
        SCComboboxOption(value: $0, label: ModeIconLabel.name(for: $0))
      }
  }

  private static let iconChoices = [
    "mic.fill",
    "sparkles",
    "bubble.left.fill",
    "note.text",
    "envelope.fill",
    "person.2.fill",
    "text.badge.checkmark",
    "quote.bubble.fill",
    "doc.text.fill",
    "command",
    "terminal.fill",
    "bolt.fill",
  ]
}

private enum ModeIconLabel {
  static func name(for systemName: String) -> String {
    systemName
      .replacingOccurrences(of: ".fill", with: "")
      .replacingOccurrences(of: ".", with: " ")
      .capitalized
  }
}
