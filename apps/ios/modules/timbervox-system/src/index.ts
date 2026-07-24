import { requireNativeModule, requireNativeView } from "expo";
import type { ComponentType } from "react";
import type { ViewProps } from "react-native";

const NativeShortcutsButton: ComponentType<ViewProps> =
  requireNativeView("TimberVoxSystem");

const TimberVoxSystem = requireNativeModule<{
  acknowledgeNativeResult: (filename: string) => void;
  clearShortcutDiagnostics: () => void;
  getKeyboardStatus: () => KeyboardStatus;
  getNativeResultOutbox: () => NativeResultOutboxItem[];
  getShortcutDiagnostics: () => string;
  markKeyboardVerificationRequired: () => void;
  presentShortcutImport: () => Promise<boolean>;
  requestNativeSessionStop: () => void;
  startKeyboardStatusObserver: () => void;
}>("TimberVoxSystem");

type KeyboardStatus = {
  fullAccess: boolean;
  keyboardSeen: boolean;
  verificationRequired: boolean;
};

type NativeResultOutboxItem = {
  filename: string;
  json: string;
};

function acknowledgeNativeResult(filename: string) {
  TimberVoxSystem.acknowledgeNativeResult(filename);
}

function getKeyboardStatus() {
  return TimberVoxSystem.getKeyboardStatus();
}

function markKeyboardVerificationRequired() {
  TimberVoxSystem.markKeyboardVerificationRequired();
}

function getNativeResultOutbox() {
  return TimberVoxSystem.getNativeResultOutbox();
}

function getShortcutDiagnostics() {
  return TimberVoxSystem.getShortcutDiagnostics();
}

function clearShortcutDiagnostics() {
  TimberVoxSystem.clearShortcutDiagnostics();
}

function presentShortcutImport() {
  return TimberVoxSystem.presentShortcutImport();
}

function requestNativeSessionStop() {
  TimberVoxSystem.requestNativeSessionStop();
}

function startKeyboardStatusObserver() {
  TimberVoxSystem.startKeyboardStatusObserver();
}

export {
  acknowledgeNativeResult,
  clearShortcutDiagnostics,
  getKeyboardStatus,
  getNativeResultOutbox,
  getShortcutDiagnostics,
  markKeyboardVerificationRequired,
  NativeShortcutsButton,
  presentShortcutImport,
  requestNativeSessionStop,
  startKeyboardStatusObserver,
};
export type { KeyboardStatus, NativeResultOutboxItem };
