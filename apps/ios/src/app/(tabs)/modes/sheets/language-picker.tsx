import { useRouter } from "expo-router";
import { FlatList } from "react-native";

import { useModeEditor } from "@/features/modes/mode-editor-state";
import {
  languageDisplayName,
  selectedRoute,
  selectedTranscriptionModel,
} from "@/features/modes/model-catalog";
import { useModes } from "@/features/modes/mode-provider";
import { PickerOption } from "@/features/modes/picker-option";

type LanguageChoice = { code: string | null; label: string };

export default function LanguagePickerScreen() {
  const router = useRouter();
  const editor = useModeEditor();
  const { catalog } = useModes();
  const model =
    editor.draft && catalog
      ? selectedTranscriptionModel(catalog, editor.draft.asrModelId)
      : undefined;
  const route = selectedRoute(model);
  const languageChoices: LanguageChoice[] = (route?.supportedLanguages ?? [])
    .map((code) => ({
      code,
      label: languageDisplayName(code),
    }))
    .sort((left, right) => left.label.localeCompare(right.label));
  const choices: LanguageChoice[] = [
    ...(route?.supportsAutomaticLanguage
      ? [{ code: null, label: "Automatic" }]
      : []),
    ...languageChoices,
  ];

  return (
    <FlatList
      className="bg-background flex-1"
      contentContainerStyle={{ gap: 10, padding: 18, paddingBottom: 40 }}
      data={choices}
      keyExtractor={(item) => item.code ?? "automatic"}
      renderItem={({ item }) => (
        <PickerOption
          label={item.label}
          onPress={() => {
            editor.patch({ language: item.code });
            router.back();
          }}
          selected={editor.draft?.language === item.code}
        />
      )}
    />
  );
}
