import SwiftUI

struct KeyChip: View {
  let text: String

  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Theme.chipSurface, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
  }
}
