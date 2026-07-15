import SwiftUI

extension Theme {
  static let timberVox = Theme(
    background: .adaptive(
      light: Color(red: 240 / 255, green: 240 / 255, blue: 240 / 255),
      dark: Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255)
    ),
    foreground: .adaptive(
      light: Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255),
      dark: Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)
    ),
    card: .adaptive(
      light: Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255),
      dark: Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255)
    ),
    cardForeground: .adaptive(
      light: Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255),
      dark: Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)
    ),
    popover: .adaptive(
      light: Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255),
      dark: Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255)
    ),
    popoverForeground: .adaptive(
      light: Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255),
      dark: Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)
    ),
    primary: Color(red: 8 / 255, green: 112 / 255, blue: 248 / 255),
    primaryForeground: .white,
    secondary: .adaptive(
      light: Color(red: 232 / 255, green: 232 / 255, blue: 232 / 255),
      dark: Color(red: 32 / 255, green: 32 / 255, blue: 32 / 255)
    ),
    secondaryForeground: .adaptive(
      light: Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255),
      dark: Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)
    ),
    muted: .adaptive(
      light: Color(red: 232 / 255, green: 232 / 255, blue: 232 / 255),
      dark: Color(red: 32 / 255, green: 32 / 255, blue: 32 / 255)
    ),
    mutedForeground: .adaptive(
      light: Color(red: 111 / 255, green: 111 / 255, blue: 111 / 255),
      dark: Color(red: 160 / 255, green: 160 / 255, blue: 160 / 255)
    ),
    accent: .adaptive(
      light: Color(red: 232 / 255, green: 232 / 255, blue: 232 / 255),
      dark: Color(red: 48 / 255, green: 48 / 255, blue: 48 / 255)
    ),
    accentForeground: .adaptive(
      light: Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255),
      dark: Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)
    ),
    destructive: .adaptive(light: .red600, dark: .red700),
    border: .adaptive(
      light: Color(red: 216 / 255, green: 216 / 255, blue: 216 / 255),
      dark: Color(red: 64 / 255, green: 64 / 255, blue: 64 / 255)
    ),
    input: .adaptive(
      light: Color(red: 216 / 255, green: 216 / 255, blue: 216 / 255),
      dark: Color(red: 64 / 255, green: 64 / 255, blue: 64 / 255)
    ),
    ring: .adaptive(light: .zinc400, dark: .zinc500),
    chart1: .adaptive(light: Color(hex: 0xE8734A), dark: Color(hex: 0x2662D9)),
    chart2: .adaptive(light: Color(hex: 0x2A9D90), dark: Color(hex: 0x2EB88A)),
    chart3: .adaptive(light: Color(hex: 0x274754), dark: Color(hex: 0xE88C30)),
    chart4: .adaptive(light: Color(hex: 0xE8C468), dark: Color(hex: 0xAF57DB)),
    chart5: .adaptive(light: Color(hex: 0xF4A462), dark: Color(hex: 0xE23670)),
    sidebar: .adaptive(
      light: Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255),
      dark: Color(red: 32 / 255, green: 32 / 255, blue: 32 / 255)
    ),
    sidebarForeground: .adaptive(
      light: Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255),
      dark: Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)
    ),
    sidebarPrimary: Color(red: 8 / 255, green: 112 / 255, blue: 248 / 255),
    sidebarPrimaryForeground: .white,
    sidebarAccent: .adaptive(
      light: Color(red: 232 / 255, green: 232 / 255, blue: 232 / 255),
      dark: Color(red: 48 / 255, green: 48 / 255, blue: 48 / 255)
    ),
    sidebarAccentForeground: .adaptive(
      light: Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255),
      dark: Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)
    ),
    sidebarBorder: .adaptive(
      light: Color(red: 216 / 255, green: 216 / 255, blue: 216 / 255),
      dark: Color(red: 64 / 255, green: 64 / 255, blue: 64 / 255)
    ),
    sidebarRing: .adaptive(light: .zinc400, dark: .zinc500),
    radius: 10
  )
}
