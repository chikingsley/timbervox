import Inject
import SwiftUI

struct PrototypeOnboardingView: View {
  let dismiss: () -> Void
  @State private var step = 0
  @State private var microphoneGranted = false
  @State private var accessibilityGranted = false
  @State private var trialText = ""
  @State private var didDictate = false
  @ObserveInjection var injection

  private let stepCount = 5

  var body: some View {
    VStack(spacing: 0) {
      ProgressView(value: Double(step + 1), total: Double(stepCount))
        .padding([.horizontal, .top])

      Group {
        switch step {
        case 0: welcome
        case 1: microphone
        case 2: accessibility
        case 3: firstDictation
        default: completion
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(36)

      Divider()
      HStack {
        if step > 0 {
          Button("Back") { step -= 1 }
        } else {
          Button("Skip Setup", action: dismiss)
        }
        Spacer()
        Button(step == stepCount - 1 ? "Done" : "Continue") {
          if step == stepCount - 1 {
            dismiss()
          } else {
            step += 1
          }
        }
        .buttonStyle(.borderedProminent)
      }
      .padding()
    }
    .frame(width: 640, height: 500)
    .enableInjection()
  }

  private var welcome: some View {
    VStack(spacing: 18) {
      Image(systemName: "waveform.circle.fill")
        .font(.system(size: 64))
        .foregroundStyle(.tint)
      Text("Welcome to TimberVox")
        .font(.largeTitle)
        .fontWeight(.semibold)
      Text("Speak naturally, then deliver clear text into the app where you are working.")
        .font(.title3)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 440)
    }
  }

  private var microphone: some View {
    permissionStep(
      title: "Allow Microphone Access", systemImage: "mic.circle",
      explanation: "TimberVox captures audio only when you intentionally start a dictation.",
      granted: $microphoneGranted)
  }

  private var accessibility: some View {
    permissionStep(
      title: "Allow Accessibility Access", systemImage: "accessibility",
      explanation: "This lets TimberVox deliver text into the frontmost app and use supported selection context.",
      granted: $accessibilityGranted)
  }

  private func permissionStep(
    title: String,
    systemImage: String,
    explanation: String,
    granted: Binding<Bool>
  ) -> some View {
    VStack(spacing: 18) {
      Image(systemName: systemImage)
        .font(.system(size: 56))
        .foregroundStyle(.tint)
      Text(title)
        .font(.title)
        .fontWeight(.semibold)
      Text(explanation)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 440)
      if granted.wrappedValue {
        Label("Granted", systemImage: "checkmark.circle.fill")
          .font(.title3)
          .foregroundStyle(.green)
      } else {
        Button("Grant") { granted.wrappedValue = true }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
      }
    }
  }

  private var firstDictation: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Try Your First Dictation")
        .font(.title)
        .fontWeight(.semibold)
      Text(
        "Click in the field, press ⌥ Space, and say the sentence below. The large recording pill appears while TimberVox listens."
      )
      .foregroundStyle(.secondary)
      Text("“TimberVox is ready for my next idea.”")
        .font(.title3)
      TextEditor(text: $trialText)
        .font(.body)
        .frame(minHeight: 110)
        .overlay {
          RoundedRectangle(cornerRadius: 6)
            .stroke(.separator)
        }
      HStack {
        Button("Simulate Dictation", systemImage: "mic.fill") {
          trialText = "TimberVox is ready for my next idea."
          didDictate = true
        }
        if didDictate {
          Label("Text delivered", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
        }
      }
    }
  }

  private var completion: some View {
    VStack(spacing: 18) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 64))
        .foregroundStyle(.green)
      Text("TimberVox Is Ready")
        .font(.largeTitle)
        .fontWeight(.semibold)
      Text("Press ⌥ Space anywhere to dictate with Voice to Text mode.")
        .font(.title3)
      LabeledContent("Change the shortcut", value: "Settings → Shortcuts")
      LabeledContent("Reopen this assistant", value: "TimberVox → Setup Assistant")
        .foregroundStyle(.secondary)
    }
  }
}

#Preview("Setup Assistant") {
  PrototypeOnboardingView {}
}
