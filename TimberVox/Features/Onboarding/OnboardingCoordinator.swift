import Observation

@MainActor
@Observable
final class OnboardingCoordinator {
  enum Step: Int, CaseIterable {
    case welcome
    case permissions
    case firstDictation
    case complete
  }

  private(set) var step: Step = .welcome
  let permissions: PermissionCoordinator

  var progressIndex: Int {
    step.rawValue
  }

  var canContinue: Bool {
    switch step {
    case .welcome, .complete:
      true
    case .permissions:
      permissions.allRequiredPermissionsGranted
    case .firstDictation:
      false
    }
  }

  init(permissions: PermissionCoordinator) {
    self.permissions = permissions
  }

  func continueFromCurrentStep(hasCompletedDictation: Bool) {
    switch step {
    case .welcome:
      permissions.refresh()
      step = permissions.allRequiredPermissionsGranted ? .firstDictation : .permissions
    case .permissions:
      guard permissions.allRequiredPermissionsGranted else { return }
      step = .firstDictation
    case .firstDictation:
      guard hasCompletedDictation else { return }
      step = .complete
    case .complete:
      break
    }
  }

  func firstDictationWasPasted(transcript: String?, fieldText: String) -> Bool {
    guard let transcript, !transcript.isEmpty else { return false }
    return fieldText.contains(transcript)
  }
}
