import {
  clearShortcutDiagnostics as clearNativeShortcutDiagnostics,
  getShortcutDiagnostics,
} from "timbervox-system";

type ShortcutDiagnosticEvent = {
  appBuild: string;
  appVersion: string;
  bundleIdentifier: string;
  errorCode?: number;
  errorDomain?: string;
  errorMessage?: string;
  operatingSystem: string;
  processIdentifier: number;
  processName: string;
  requestId?: string;
  schemaVersion: number;
  step: string;
  timestamp: string;
};

type ShortcutDiagnosticsExport = {
  events: ShortcutDiagnosticEvent[];
  exportedAt: string;
  schemaVersion: number;
};

const EMPTY_EXPORT: ShortcutDiagnosticsExport = {
  events: [],
  exportedAt: "",
  schemaVersion: 1,
};

function loadShortcutDiagnostics() {
  try {
    const payload = JSON.parse(
      getShortcutDiagnostics(),
    ) as ShortcutDiagnosticsExport;
    if (!Array.isArray(payload.events)) return EMPTY_EXPORT;
    return payload;
  } catch {
    return EMPTY_EXPORT;
  }
}

function clearShortcutDiagnostics() {
  clearNativeShortcutDiagnostics();
}

export { clearShortcutDiagnostics, loadShortcutDiagnostics };
export type { ShortcutDiagnosticEvent, ShortcutDiagnosticsExport };
