import { ExtensionStorage } from "@bacons/apple-targets";
import * as Linking from "expo-linking";
import { useCallback, useEffect, useState } from "react";
import { AppState } from "react-native";

const APP_GROUP = "group.com.chiejimofor.timbervox";
const storage = new ExtensionStorage(APP_GROUP);

export type SetupState = {
  completed: boolean;
  keyboardVerified: boolean;
};

export function useSetupState() {
  const [state, setState] = useState(readSetupState);
  const refresh = useCallback(() => setState(readSetupState()), []);

  useEffect(() => {
    const subscription = AppState.addEventListener("change", (nextState) => {
      if (nextState === "active") refresh();
    });
    return () => subscription.remove();
  }, [refresh]);

  const complete = useCallback(() => {
    storage.set("onboardingComplete", 1);
    setState((current) => ({ ...current, completed: true }));
  }, []);

  const restart = useCallback(() => {
    storage.set("onboardingComplete", 0);
    setState((current) => ({ ...current, completed: false }));
  }, []);

  return {
    ...state,
    complete,
    openSettings: () => Linking.openSettings(),
    refresh,
    restart,
  };
}

function readSetupState(): SetupState {
  return {
    completed: Number(storage.get("onboardingComplete") ?? 0) > 0,
    keyboardVerified:
      Number(storage.get("keyboardSeen") ?? 0) > 0 &&
      Number(storage.get("keyboardHasFullAccess") ?? 0) > 0,
  };
}
