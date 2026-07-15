// ============================================================
// Toggle.swift — swiftcn-ui
// Depends on: Theme/
// ============================================================
import SwiftUI

// MARK: - Variants

public enum SCToggleVariant: CaseIterable, Sendable {
  case `default`, outline
}

public enum SCToggleSize: CaseIterable, Sendable {
  case `default`, sm, lg
}

// MARK: - Style

/// shadcn's Toggle: a two-state pressed button (think a toolbar Bold button),
/// not a switch. Apply it to a native `Toggle` — behavior and accessibility
/// stay native; this supplies the style layer only.
///
///     Toggle("Bold", systemImage: "bold", isOn: $isBold)
///         .toggleStyle(.scToggle())
///         .labelStyle(.iconOnly)
///     Toggle("Italic", isOn: $isItalic)
///         .toggleStyle(.scToggle(variant: .outline, size: .sm))
public struct SCToggleStyle: ToggleStyle {
  @Environment(\.isEnabled) private var isEnabled
  @FocusState private var isFocused: Bool

  var variant: SCToggleVariant
  var size: SCToggleSize

  public init(variant: SCToggleVariant = .default, size: SCToggleSize = .default) {
    self.variant = variant
    self.size = size
  }

  public func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      configuration.label
    }
    .buttonStyle(
      SCToggleButtonStyle(
        variant: variant,
        size: size,
        isOn: configuration.isOn,
        isFocused: isFocused
      )
    )
    .focused($isFocused)
    .opacity(isEnabled ? 1 : 0.5)
    .animation(.easeOut(duration: 0.12), value: configuration.isOn)
    .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
  }
}

extension ToggleStyle where Self == SCToggleStyle {
  public static func scToggle(variant: SCToggleVariant = .default, size: SCToggleSize = .default) -> SCToggleStyle {
    SCToggleStyle(variant: variant, size: size)
  }
}

// MARK: - Inner button style

/// Shared visual engine for native toggle and toggle-group buttons.
public struct SCToggleButtonStyle: ButtonStyle {
  @Environment(\.theme) private var theme

  private let variant: SCToggleVariant
  private let size: SCToggleSize
  private let isOn: Bool
  private let isFocused: Bool
  private let isConnected: Bool

  public init(
    variant: SCToggleVariant = .default,
    size: SCToggleSize = .default,
    isOn: Bool,
    isFocused: Bool = false,
    isConnected: Bool = false
  ) {
    self.variant = variant
    self.size = size
    self.isOn = isOn
    self.isFocused = isFocused
    self.isConnected = isConnected
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(font)
      .lineLimit(1)
      .padding(padding)
      .frame(minWidth: height, minHeight: height)
      .background(background(pressed: configuration.isPressed), in: shape)
      .overlay {
        if variant == .outline {
          shape.strokeBorder(theme.border)
        }
      }
      .overlay {
        if isFocused {
          shape
            .stroke(theme.ring, lineWidth: 2)
            .padding(-2)
        }
      }
      .foregroundStyle(isOn ? theme.accentForeground : theme.foreground)
      .contentShape(shape)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: isConnected ? 0 : theme.radius,
      style: .continuous
    )
  }

  private func background(pressed: Bool) -> Color {
    if isOn {
      return pressed ? theme.accent.opacity(0.85) : theme.accent
    }
    if pressed {
      return variant == .outline ? theme.accent : theme.muted
    }
    return variant == .outline ? theme.background : .clear
  }

  private var font: Font {
    switch size {
    case .sm: .footnote.weight(.medium)
    default: .subheadline.weight(.medium)
    }
  }

  private var padding: EdgeInsets {
    switch size {
    case .default: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    case .sm: EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    case .lg: EdgeInsets(top: 10, leading: 32, bottom: 10, trailing: 32)
    }
  }

  private var height: CGFloat {
    switch size {
    case .default: 40
    case .sm: 36
    case .lg: 44
    }
  }
}
