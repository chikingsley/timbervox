import SwiftUI

struct InsetDivider: View {
  var leadingInset: CGFloat = 16
  var trailingInset: CGFloat = 16

  var body: some View {
    Divider()
      .padding(.leading, leadingInset)
      .padding(.trailing, trailingInset)
  }
}
