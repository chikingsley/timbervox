import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useMemo,
  useState,
} from "react";

import type { ModeDraft, ModePresetKind } from "@/features/modes/mode-types";
import { applyPreset } from "@/features/modes/preset-contracts";

type ModeEditorContextValue = {
  begin: (draft: ModeDraft) => void;
  chooseIcon: (iconKey: string) => void;
  choosePreset: (presetKind: ModePresetKind) => void;
  draft: ModeDraft | null;
  patch: (values: Partial<ModeDraft>) => void;
};

const ModeEditorContext = createContext<ModeEditorContextValue | null>(null);

function ModeEditorProvider({ children }: PropsWithChildren) {
  const [draft, setDraft] = useState<ModeDraft | null>(null);
  const begin = useCallback((nextDraft: ModeDraft) => setDraft(nextDraft), []);
  const patch = useCallback(
    (values: Partial<ModeDraft>) =>
      setDraft((current) => (current ? { ...current, ...values } : current)),
    [],
  );
  const chooseIcon = useCallback(
    (iconKey: string) => patch({ iconCustomized: true, iconKey }),
    [patch],
  );
  const choosePreset = useCallback(
    (presetKind: ModePresetKind) =>
      setDraft((current) =>
        current ? applyPreset(current, presetKind) : current,
      ),
    [],
  );
  const value = useMemo(
    () => ({ begin, chooseIcon, choosePreset, draft, patch }),
    [begin, chooseIcon, choosePreset, draft, patch],
  );
  return (
    <ModeEditorContext.Provider value={value}>
      {children}
    </ModeEditorContext.Provider>
  );
}

function useModeEditor() {
  const value = useContext(ModeEditorContext);
  if (!value) {
    throw new Error("useModeEditor must be used inside ModeEditorProvider");
  }
  return value;
}

export { ModeEditorProvider, useModeEditor };
