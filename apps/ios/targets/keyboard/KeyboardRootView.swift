import SwiftUI

enum KeyboardMetrics {
  static let suggestionHeight: CGFloat = 40
  static let keySurfaceHeight: CGFloat = 148
  static let bottomRowHeight: CGFloat = 44
  static let sectionSpacing: CGFloat = 5
  static let horizontalPadding: CGFloat = 5
  static let verticalPadding: CGFloat = 4
  static let totalHeight =
    suggestionHeight + keySurfaceHeight + bottomRowHeight + sectionSpacing * 2
    + verticalPadding * 2
}

struct KeyboardRootView: View {
  @ObservedObject var model: KeyboardModel

  var body: some View {
    VStack(spacing: KeyboardMetrics.sectionSpacing) {
      KeyboardSuggestionBar(
        suggestions: model.predictions,
        partialTranscript: model.streamingInsertionEnabled ? "" : model.partialTranscript,
        notice: model.notice,
        isEnabled: model.predictionsEnabled,
        onSelect: model.acceptPrediction,
        onNoticeTap: model.acceptNotice
      )
      Group {
        if model.page == .letters {
          SwipeKeySurface(model: model)
        } else {
          AlternateKeySurface(model: model)
        }
      }
      .frame(height: KeyboardMetrics.keySurfaceHeight)
      bottomRow
        .frame(height: KeyboardMetrics.bottomRowHeight)
    }
    .padding(.horizontal, KeyboardMetrics.horizontalPadding)
    .padding(.vertical, KeyboardMetrics.verticalPadding)
    .frame(maxWidth: .infinity)
    .frame(height: KeyboardMetrics.totalHeight)
    .background(Color.clear)
  }

  private var bottomRow: some View {
    HStack(spacing: 5) {
      Button {
        if model.page == .letters {
          model.showNumbers()
        } else {
          model.showLetters()
        }
      } label: {
        Text(model.page == .letters ? "123" : "ABC")
          .font(.system(size: 13, weight: .medium))
          .frame(width: 43, height: 44)
      }
      .buttonStyle(KeyboardSpecialKeyStyle())

      if model.needsGlobe {
        KeyboardModeSwitchButton(controller: model.controller)
          .frame(width: 40, height: 44)
      }

      if let contextualKey {
        // The frame must live on the label: KeyboardKeyStyle draws its key
        // background around the label, so framing the button instead leaves a
        // glyph-sized sliver of key floating in empty space.
        Button {
          model.insert(contextualKey)
        } label: {
          Text(contextualKey)
            .font(.system(size: 17))
            .frame(width: 38, height: 44)
        }
        .buttonStyle(KeyboardKeyStyle())
      }

      Button(action: model.insertSpace) {
        Text("space")
          .font(.system(size: 14))
          .frame(maxWidth: .infinity, minHeight: 44)
      }
      .buttonStyle(KeyboardKeyStyle())

      // The return key keeps one identity everywhere instead of relabeling
      // itself go/search/send per host field.
      Button(action: model.insertReturn) {
        Image(systemName: "return")
          .font(.system(size: 17, weight: .medium))
          .frame(width: 48, height: 44)
      }
      .buttonStyle(KeyboardSpecialKeyStyle())
      .accessibilityLabel("Return")

      DictationKey(state: model.dictationKeyState, action: model.toggleDictation)
    }
  }

  private var contextualKey: String? {
    switch model.keyboardType {
    case .emailAddress: "@"
    case .URL: "/"
    case .twitter: "#"
    case .webSearch: "."
    default: nil
    }
  }
}

/// The dictation key carries every dictation state itself. Nothing about
/// connecting, recording, or processing is written into the suggestion row.
private struct DictationKey: View {
  let state: DictationKeyState
  let action: () -> Void

  var body: some View {
    control
      .accessibilityLabel(voiceOverLabel)
      .accessibilityIdentifier("timbervox-dictation")
  }

  // A keyboard extension has no supported way to open its host app —
  // extensionContext.open is documented for Today widgets only and the
  // responder-chain openURL hack stopped working in iOS 18 — but a SwiftUI
  // Link may open a URL, so the offline key is a Link straight into TimberVox.
  @ViewBuilder private var control: some View {
    if state == .offline, let url = URL(string: "timbervox://session") {
      Link(destination: url) { keyFace }
    } else {
      Button(action: action) { keyFace }
    }
  }

  private var keyFace: some View {
    symbol
      .font(.system(size: 17, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 46, height: 44)
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay {
        if state == .recording {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(.white.opacity(0.45), lineWidth: 2)
            .allowsHitTesting(false)
        } else if state == .offline {
          Image(systemName: "arrow.up.forward.app.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(3)
            .allowsHitTesting(false)
        }
      }
  }

  @ViewBuilder private var symbol: some View {
    switch state {
    case .restricted:
      Image(systemName: "mic.slash.fill")
    case .offline:
      Image(systemName: "mic.fill")
    case .idle:
      Image(systemName: "mic.fill")
    case .recording:
      Image(systemName: "stop.fill")
    case .processing:
      ProgressView()
        .progressViewStyle(.circular)
        .tint(.white)
        .scaleEffect(0.7)
    }
  }

  private var background: Color {
    switch state {
    case .restricted, .offline: Color(uiColor: .systemGray)
    case .idle: Color.accentColor
    case .recording: Color.red
    case .processing: Color.accentColor.opacity(0.55)
    }
  }

  private var voiceOverLabel: String {
    switch state {
    case .restricted: "Dictation unavailable, Full Access is off"
    case .offline: "Open TimberVox to start a dictation session"
    case .idle: "Start dictation"
    case .recording: "Stop dictation"
    case .processing: "Finishing dictation"
    }
  }
}

private struct KeyboardModeSwitchButton: UIViewRepresentable {
  let controller: UIInputViewController?

  func makeUIView(context: Context) -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(UIImage(systemName: "globe"), for: .normal)
    button.tintColor = .label
    button.backgroundColor = KeyboardPalette.specialUIColor
    button.layer.cornerRadius = 7
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOpacity = 0.18
    button.layer.shadowRadius = 0.5
    button.layer.shadowOffset = CGSize(width: 0, height: 1)
    if let controller {
      button.addTarget(
        controller,
        action: #selector(UIInputViewController.handleInputModeList(from:with:)),
        for: .allTouchEvents
      )
    }
    return button
  }

  func updateUIView(_ button: UIButton, context: Context) {}
}

struct KeyboardKeyStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .background(configuration.isPressed ? KeyboardPalette.pressedKey : KeyboardPalette.key)
      .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      .shadow(color: .black.opacity(0.18), radius: 0.5, y: 1)
  }
}

struct KeyboardSpecialKeyStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .background(
        configuration.isPressed ? KeyboardPalette.pressedSpecialKey : KeyboardPalette.specialKey
      )
      .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      .shadow(color: .black.opacity(0.12), radius: 0.5, y: 1)
  }
}
