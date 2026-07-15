import { Redirect, useFocusEffect, useLocalSearchParams } from "expo-router";
import { useCallback } from "react";

import { AppScreen } from "@/components/app/app-screen";
import { Text } from "@/components/ui/text";
import { ModeEditorScreen } from "@/features/modes/mode-editor-screen";
import { useModeEditor } from "@/features/modes/mode-editor-state";
import { existingModeEditorState } from "@/features/modes/mode-editor-contract";
import { useModes } from "@/features/modes/mode-provider";
import { modeToDraft } from "@/features/modes/mode-validation";

export default function EditModeScreen() {
  const { modeId: routeModeId } = useLocalSearchParams<{
    modeId: string | string[];
  }>();
  const modeId = Array.isArray(routeModeId) ? routeModeId[0] : routeModeId;
  const editor = useModeEditor();
  const modes = useModes();
  const stored = modes.modes.find((mode) => mode.id === modeId);
  const state = existingModeEditorState({
    draftId: editor.draft?.id,
    modeId,
    modesLoading: modes.loading,
    storedModeExists: Boolean(stored),
  });

  useFocusEffect(
    useCallback(() => {
      if (editor.draft?.id === modeId) return;
      if (stored) editor.begin(modeToDraft(stored));
    }, [editor, modeId, stored]),
  );

  if (state === "missing") return <Redirect href="/modes" />;
  if (state === "loading") {
    return (
      <AppScreen contentClassName="items-center justify-center px-6">
        <Text className="text-muted-foreground">Loading mode…</Text>
      </AppScreen>
    );
  }
  return <ModeEditorScreen isNew={false} />;
}
