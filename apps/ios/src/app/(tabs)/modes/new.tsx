import { useFocusEffect } from "expo-router";
import { useCallback, useRef } from "react";

import { ModeEditorScreen } from "@/features/modes/mode-editor-screen";
import { useModeEditor } from "@/features/modes/mode-editor-state";
import { defaultTranscriptionModel } from "@/features/modes/model-catalog";
import { useModes } from "@/features/modes/mode-provider";
import { createModeDraft } from "@/features/modes/preset-contracts";

export default function NewModeScreen() {
  const editor = useModeEditor();
  const { catalog } = useModes();
  const draftRef = useRef(createModeDraft());

  useFocusEffect(
    useCallback(() => {
      if (editor.draft?.id === draftRef.current.id) return;
      const model = catalog ? defaultTranscriptionModel(catalog) : undefined;
      draftRef.current = {
        ...draftRef.current,
        asrModelId: model?.id ?? "",
        realtimeEnabled: Boolean(model?.realtime),
      };
      editor.begin(draftRef.current);
    }, [catalog, editor]),
  );

  return <ModeEditorScreen isNew />;
}
