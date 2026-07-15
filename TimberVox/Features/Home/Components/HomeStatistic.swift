import SwiftUI

struct HomeStatistic: View {
  let value: String
  let label: String
  var showsDivider = true
  @Environment(\.theme) private var theme

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.system(size: 16, weight: .semibold))
        .monospacedDigit()
      Text(label)
        .font(.system(size: 11))
        .foregroundStyle(theme.mutedForeground)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .trailing) {
      if showsDivider {
        SCSeparator(.vertical)
          .frame(height: 36)
          .opacity(0.6)
      }
    }
  }
}
