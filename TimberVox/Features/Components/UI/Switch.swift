// ============================================================
// Switch.swift — swiftcn-ui
// Depends on: Field.swift, Theme/
// ============================================================
import SwiftUI

// MARK: - Primitive

/// The two sizes documented by shadcn/ui's Switch.
public enum SCSwitchSize: Hashable, Sendable {
  case small
  case `default`

  fileprivate var trackSize: CGSize {
    switch self {
    case .small: CGSize(width: 28, height: 16)
    case .default: CGSize(width: 32, height: 18)
    }
  }

  fileprivate var thumbDiameter: CGFloat {
    switch self {
    case .small: 12
    case .default: 14
    }
  }
}

/// A caller-controlled switch matching shadcn/ui's standalone Switch root.
/// Compose it beside `SCFieldLabel` and `SCFieldDescription`, or use the
/// `SCSwitchStyle` convenience when a native `Toggle` label is preferable.
///
/// The label supplied here is for accessibility; the visual Field label stays
/// independently composable, matching the upstream examples.
public struct SCSwitch: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var environmentIsEnabled
  @Environment(\.scFieldInvalid) private var fieldIsInvalid

  @Binding private var isOn: Bool
  private let accessibilityLabel: String
  private let size: SCSwitchSize
  private let invalidOverride: SCFieldInvalidState
  private let isDisabled: Bool

  @FocusState private var isFocused: Bool

  public init(
    _ accessibilityLabel: String,
    isOn: Binding<Bool>,
    size: SCSwitchSize = .default,
    isInvalid: SCFieldInvalidState = .inherited,
    isDisabled: Bool = false
  ) {
    self.accessibilityLabel = accessibilityLabel
    self._isOn = isOn
    self.size = size
    self.invalidOverride = isInvalid
    self.isDisabled = isDisabled
  }

  public var body: some View {
    Button {
      isOn.toggle()
    } label: {
      SCSwitchTrack(
        isOn: isOn,
        size: size,
        isInvalid: isInvalid,
        isFocused: isFocused,
        reduceMotion: reduceMotion
      )
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focused($isFocused)
    .disabled(isDisabled)
    .opacity(isEffectivelyEnabled ? 1 : 0.5)
    .accessibilityRepresentation {
      Toggle(accessibilityLabel, isOn: $isOn)
        .toggleStyle(.switch)
        .disabled(isDisabled)
    }
    .accessibilityHint(isInvalid ? "Invalid selection" : "")
  }

  private var isInvalid: Bool {
    invalidOverride.resolve(inherited: fieldIsInvalid)
  }

  private var isEffectivelyEnabled: Bool {
    environmentIsEnabled && !isDisabled
  }
}

private struct SCSwitchTrack: View {
  @Environment(\.theme) private var theme

  let isOn: Bool
  let size: SCSwitchSize
  let isInvalid: Bool
  let isFocused: Bool
  let reduceMotion: Bool

  var body: some View {
    HStack(spacing: 0) {
      if placesThumbAtLeading {
        thumb
        Spacer(minLength: 0)
      } else {
        Spacer(minLength: 0)
        thumb
      }
    }
    .padding(2)
    .frame(width: size.trackSize.width, height: size.trackSize.height)
    .background(isOn ? theme.primary : theme.input, in: Capsule())
    .overlay {
      if isInvalid {
        Capsule()
          .stroke(theme.destructive, lineWidth: 1)
      }
    }
    .overlay {
      if isFocused || isInvalid {
        Capsule()
          .stroke(focusColor.opacity(0.45), lineWidth: 3)
          .padding(-3)
      }
    }
    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isOn)
    .accessibilityHidden(true)
  }

  private var thumb: some View {
    Circle()
      .fill(theme.background)
      .frame(width: size.thumbDiameter, height: size.thumbDiameter)
      .shadow(color: theme.foreground.opacity(0.12), radius: 1, y: 1)
  }

  /// HStack maps leading/trailing to the current layout direction.
  private var placesThumbAtLeading: Bool {
    !isOn
  }

  private var focusColor: Color {
    isInvalid ? theme.destructive : theme.ring
  }
}

// MARK: - Native Toggle style

/// Switch appearance for a native SwiftUI `Toggle`. The whole label row is
/// activatable, while the same track, size, Field-invalid state, disabled
/// treatment, focus ring, Reduce Motion behavior, and RTL geometry are shared
/// with `SCSwitch`.
public struct SCSwitchStyle: ToggleStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.scFieldInvalid) private var fieldIsInvalid
  @Environment(\.theme) private var theme

  private let size: SCSwitchSize
  private let invalidOverride: SCFieldInvalidState

  @FocusState private var isFocused: Bool

  public init(
    size: SCSwitchSize = .default,
    isInvalid: SCFieldInvalidState = .inherited
  ) {
    self.size = size
    self.invalidOverride = isInvalid
  }

  public func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      HStack(spacing: 12) {
        configuration.label
          .font(.subheadline)
          .foregroundStyle(theme.foreground)
        Spacer(minLength: 8)
        SCSwitchTrack(
          isOn: configuration.isOn,
          size: size,
          isInvalid: invalidOverride.resolve(inherited: fieldIsInvalid),
          isFocused: isFocused,
          reduceMotion: reduceMotion
        )
      }
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focused($isFocused)
    .opacity(isEnabled ? 1 : 0.5)
    .accessibilityRepresentation {
      Toggle(isOn: accessibilityBinding(configuration)) {
        configuration.label
      }
      .toggleStyle(.switch)
    }
  }

  private func accessibilityBinding(_ configuration: Configuration) -> Binding<Bool> {
    Binding(
      get: { configuration.isOn },
      set: { configuration.isOn = $0 }
    )
  }
}

extension ToggleStyle where Self == SCSwitchStyle {
  /// `Toggle("Airplane Mode", isOn: $enabled).toggleStyle(.scSwitch)`
  public static var scSwitch: SCSwitchStyle { SCSwitchStyle() }

  /// Creates the shared switch style with an upstream size and optional
  /// explicit invalid-state override.
  public static func scSwitch(
    size: SCSwitchSize,
    isInvalid: SCFieldInvalidState = .inherited
  ) -> SCSwitchStyle {
    SCSwitchStyle(size: size, isInvalid: isInvalid)
  }
}
