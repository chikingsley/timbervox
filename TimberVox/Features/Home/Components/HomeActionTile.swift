import SwiftUI

struct HomeActionTile: View {
  let title: String
  let icon: String
  var shortcut: String?
  var isEnabled = true
  let action: () -> Void
  @Environment(\.theme) private var theme

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: icon)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.mutedForeground)
            .frame(width: 28, height: 28)
            .background(theme.muted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

          Spacer(minLength: 0)

          if let shortcut {
            SCKbd(shortcut)
          }
        }

        Spacer(minLength: 8)

        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
    }
    .buttonStyle(.sc(.secondary))
    .disabled(!isEnabled)
  }
}
