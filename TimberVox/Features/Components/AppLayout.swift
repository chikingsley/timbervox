import SwiftUI

enum AppSpacing {
  static let xs: CGFloat = 4
  static let sm: CGFloat = 8
  static let md: CGFloat = 12
  static let lg: CGFloat = 16
  static let xl: CGFloat = 24
}

enum AppLayout {
  static let contentMaxWidth: CGFloat = 860
  static let headerHeight: CGFloat = 48
}

extension View {
  func appContentColumn(
    topInset: CGFloat = 0,
    bottomInset: CGFloat = 0
  ) -> some View {
    frame(maxWidth: AppLayout.contentMaxWidth)
      .padding(.horizontal, AppSpacing.lg)
      .padding(.top, topInset)
      .padding(.bottom, bottomInset)
      .frame(maxWidth: .infinity)
  }
}
