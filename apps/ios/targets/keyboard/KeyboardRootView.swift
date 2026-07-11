import SwiftUI

struct KeyboardRootView: View {
  @ObservedObject var model: KeyboardModel

  var body: some View {
    VStack(spacing: 7) {
      predictionBar
      SwipeKeySurface(model: model)
        .frame(height: 142)
      bottomRow
    }
    .padding(.horizontal, 5)
    .padding(.top, 6)
    .padding(.bottom, 4)
    .background(Color(uiColor: .systemGray5))
  }

  private var predictionBar: some View {
    HStack(spacing: 0) {
      ForEach(Array(model.predictions.prefix(3).enumerated()), id: \.offset) { index, word in
        Button(word) { model.acceptPrediction(word) }
          .font(.system(size: 14, weight: index == 0 ? .semibold : .regular))
          .lineLimit(1)
          .frame(maxWidth: .infinity, minHeight: 31)
        if index < 2 {
          Divider().frame(height: 20)
        }
      }
    }
    .overlay(alignment: .bottom) {
      if !model.partialTranscript.isEmpty {
        Text(model.partialTranscript)
          .font(.system(size: 12, weight: .medium))
          .lineLimit(1)
          .padding(.horizontal, 10)
          .frame(maxWidth: .infinity, minHeight: 31)
          .background(.thinMaterial)
      }
    }
  }

  private var bottomRow: some View {
    HStack(spacing: 6) {
      if model.needsGlobe {
        keyButton(systemName: "globe", width: 42, action: model.advanceKeyboard)
      }
      keyButton(systemName: model.shifted ? "shift.fill" : "shift", width: 42, action: model.toggleShift)
      keyButton(systemName: "delete.left", width: 46, action: model.deleteBackward)
      Button(action: model.insertSpace) {
        Text("space")
          .font(.system(size: 14))
          .frame(maxWidth: .infinity, minHeight: 44)
      }
      .buttonStyle(KeyboardKeyStyle())
      keyButton(systemName: "return", width: 48, action: model.insertReturn)
      Button(action: model.toggleDictation) {
        Image(systemName: model.recordingRequested ? "stop.fill" : "mic.fill")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 46, height: 44)
          .background(model.recordingRequested ? Color.red : Color.accentColor)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          .overlay {
            if model.recordingRequested {
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 2)
            }
          }
      }
      .accessibilityLabel(model.recordingRequested ? "Stop dictation" : "Start dictation")
    }
  }

  private func keyButton(systemName: String, width: CGFloat, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 17, weight: .medium))
        .frame(width: width, height: 44)
    }
    .buttonStyle(KeyboardKeyStyle())
  }
}

private struct KeyboardKeyStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .background(configuration.isPressed ? Color(uiColor: .systemGray3) : Color(uiColor: .systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      .shadow(color: .black.opacity(0.18), radius: 0.5, y: 1)
  }
}
