import SwiftUI

/// A grouped settings card — the ui-prototype's `SettingsCard`: a title,
/// an optional one-line description, then rows separated by hairlines.
/// Modes' `ModeSettingsPanel`/`ModeSettingsRow` predate this and should fold
/// into it once that surface settles.
struct AppSettingsCard<Content: View>: View {
  let title: String
  let description: String?
  private let content: Content

  @Environment(\.theme) private var theme

  init(_ title: String, description: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.description = description
    self.content = content()
  }

  var body: some View {
    SCCard(size: .sm) {
      VStack(alignment: .leading, spacing: AppSpacing.sm) {
        SCCardHeader {
          SCCardTitle(title)
          if let description {
            SCCardDescription(description)
          }
        }
        SCCardContent {
          VStack(alignment: .leading, spacing: AppSpacing.md) {
            content
          }
        }
      }
    }
  }
}

/// One settings row: label with an optional caption underneath, and whatever
/// control lives at the trailing edge (switch, select, shortcut recorder,
/// plain value text).
struct AppSettingsRow<Trailing: View>: View {
  let label: String
  let detail: String?
  private let trailing: Trailing

  @Environment(\.theme) private var theme

  init(
    _ label: String,
    detail: String? = nil,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.label = label
    self.detail = detail
    self.trailing = trailing()
  }

  var body: some View {
    HStack(alignment: .center, spacing: AppSpacing.lg) {
      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.system(size: 13, weight: .medium))

        if let detail {
          Text(detail)
            .font(.system(size: 11))
            .foregroundStyle(theme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Spacer(minLength: AppSpacing.lg)
      trailing
    }
    .frame(minHeight: 28)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// An info row: label on the left, a muted plain value on the right.
struct AppSettingsInfoRow: View {
  let label: String
  var detail: String?
  let value: String

  @Environment(\.theme) private var theme

  var body: some View {
    AppSettingsRow(label, detail: detail) {
      Text(value)
        .font(.system(size: 12))
        .foregroundStyle(theme.mutedForeground)
    }
  }
}
