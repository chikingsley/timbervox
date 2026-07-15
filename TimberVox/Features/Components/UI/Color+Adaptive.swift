import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

extension Color {
  /// Creates one native color that resolves to different light and dark
  /// values without colliding with similarly named dependency extensions.
  ///
  /// This is swiftcn's replacement for selecting between shadcn's `:root`
  /// and `.dark` variable values. Components never branch on `colorScheme`;
  /// the semantic color stored in `Theme` resolves through the platform's
  /// native appearance system.
  public static func adaptive(light: Color, dark: Color) -> Color {
    #if canImport(UIKit)
      Color(
        uiColor: UIColor { trait in
          trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    #elseif canImport(AppKit)
      Color(
        nsColor: NSColor(name: nil) { appearance in
          let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
          return isDark ? NSColor(dark) : NSColor(light)
        })
    #else
      light
    #endif
  }
}
