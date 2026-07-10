import Inject
import SwiftUI

struct OnboardingView: View {
  let dictation: DictationController
  let onFinish: () -> Void
  @State private var coordinator: OnboardingCoordinator
  @State private var firstDictationText = ""
  @FocusState private var firstDictationFieldIsFocused: Bool
  @ObserveInjection var injection

  init(
    dictation: DictationController,
    permissions: PermissionCoordinator,
    onFinish: @escaping () -> Void
  ) {
    self.dictation = dictation
    self.onFinish = onFinish
    _coordinator = State(initialValue: OnboardingCoordinator(permissions: permissions))
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Button("Set Up Later", action: onFinish)
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .font(.system(size: 12))
      }
      .padding(.top, 20)
      .padding(.horizontal, 24)

      Spacer()

      content
        .frame(maxWidth: 440)

      Spacer()

      progress
        .padding(.bottom, 18)

      footerButton
        .padding(.bottom, 28)
    }
    .frame(minWidth: 560, minHeight: 500)
    .onAppear {
      coordinator.permissions.refresh()
    }
    .enableInjection()
  }

  @ViewBuilder
  private var content: some View {
    switch coordinator.step {
    case .welcome:
      welcome
    case .permissions:
      permissions
    case .firstDictation:
      firstDictation
    case .complete:
      completion
    }
  }

  private var welcome: some View {
    VStack(spacing: 14) {
      Image(systemName: "waveform")
        .font(.system(size: 44, weight: .medium))
        .foregroundStyle(Color.accentColor)
      Text("Welcome to TimberVox")
        .font(.system(size: 22, weight: .semibold))
      Text(
        "Dictate anywhere on your Mac. Press a shortcut, speak, and your words land in the app you're using."
      )
      .font(.system(size: 13))
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
    }
  }

  private var permissions: some View {
    VStack(spacing: 22) {
      VStack(spacing: 8) {
        Image(systemName: "checkmark.shield")
          .font(.system(size: 40, weight: .medium))
          .foregroundStyle(Color.accentColor)
        Text("Allow TimberVox to work")
          .font(.system(size: 22, weight: .semibold))
        Text("These two permissions are required for dictation and automatic paste.")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 0) {
        PermissionRow(
          title: "Microphone",
          detail: "Records your voice only while dictation is active.",
          systemImage: "mic.fill",
          status: coordinator.permissions.microphoneStatus,
          isRequesting: coordinator.permissions.isRequestingMicrophone
        ) {
          Task { await coordinator.permissions.grantMicrophone() }
        }

        Divider()
          .padding(.leading, 42)

        PermissionRow(
          title: "Accessibility",
          detail: "Pastes the finished transcript into the app you're using.",
          systemImage: "text.cursor",
          status: coordinator.permissions.accessibilityStatus
        ) {
          coordinator.permissions.grantAccessibility()
        }
      }
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))

      if !coordinator.permissions.allRequiredPermissionsGranted {
        Text("After changing a setting, return to TimberVox. This page updates automatically.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
  }

  private var firstDictation: some View {
    VStack(spacing: 16) {
      Text("Try your first dictation")
        .font(.system(size: 22, weight: .semibold))

      Text("Click in the field, then use the shortcut. Your transcript should paste here.")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      TextField("Your dictation will appear here", text: $firstDictationText, axis: .vertical)
        .lineLimit(3...5)
        .textFieldStyle(.roundedBorder)
        .focused($firstDictationFieldIsFocused)
        .accessibilityLabel("First dictation test field")

      HStack(spacing: 6) {
        keycap("⌥")
        keycap("Space")
      }

      firstDictationStatus
    }
    .task {
      firstDictationFieldIsFocused = true
    }
  }

  @ViewBuilder
  private var firstDictationStatus: some View {
    if dictation.isRecording {
      Label("Recording — press ⌥Space again to stop", systemImage: "record.circle.fill")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.red)
    } else if hasPastedFirstDictation {
      Label("Your first dictation pasted successfully", systemImage: "checkmark.circle.fill")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.green)
    } else if dictation.lastTranscript != nil {
      Label(
        "The transcript finished but did not paste here. Check Accessibility and try again.",
        systemImage: "exclamationmark.triangle.fill"
      )
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(Color.orange)
      .multilineTextAlignment(.center)
    } else if let message = dictation.statusMessage {
      Text(message)
        .font(.system(size: 13))
        .foregroundStyle(.red)
        .multilineTextAlignment(.center)
    } else {
      Text("Press ⌥Space to start, speak, then press it again to finish.")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  private var completion: some View {
    VStack(spacing: 14) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 44, weight: .medium))
        .foregroundStyle(Color.green)
      Text("TimberVox is ready")
        .font(.system(size: 22, weight: .semibold))
      Text("Use ⌥Space whenever you want to dictate.")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
    }
  }

  private var progress: some View {
    HStack(spacing: 6) {
      ForEach(OnboardingCoordinator.Step.allCases, id: \.rawValue) { step in
        Circle()
          .fill(
            step.rawValue == coordinator.progressIndex
              ? Color.accentColor : Color.secondary.opacity(0.15)
          )
          .frame(width: 7, height: 7)
      }
    }
  }

  private var footerButton: some View {
    Button {
      if coordinator.step == .complete {
        onFinish()
      } else {
        coordinator.continueFromCurrentStep(
          hasCompletedDictation: hasPastedFirstDictation
        )
      }
    } label: {
      Text(coordinator.step == .complete ? "Open TimberVox" : "Continue")
        .frame(width: 160)
    }
    .controlSize(.large)
    .buttonStyle(.borderedProminent)
    .keyboardShortcut(.defaultAction)
    .disabled(!canUseFooterButton)
  }

  private var canUseFooterButton: Bool {
    if coordinator.step == .firstDictation {
      return hasPastedFirstDictation
    }
    return coordinator.canContinue
  }

  private var hasPastedFirstDictation: Bool {
    coordinator.firstDictationWasPasted(
      transcript: dictation.lastTranscript,
      fieldText: firstDictationText
    )
  }

  private func keycap(_ label: String) -> some View {
    Text(label)
      .font(.system(size: 15, weight: .medium))
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(Color.secondary.opacity(0.15))
      )
  }
}

private struct PermissionRow: View {
  let title: String
  let detail: String
  let systemImage: String
  let status: AppPermissionStatus
  var isRequesting = false
  let grant: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .frame(width: 24)
        .foregroundStyle(status.isGranted ? Color.green : Color.accentColor)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .fontWeight(.medium)
        Text(detail)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }

      Spacer()

      if status.isGranted {
        Label("Granted", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
      } else {
        Button("Grant", action: grant)
          .disabled(isRequesting)
      }
    }
    .padding(14)
  }
}
