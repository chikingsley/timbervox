import { useRouter } from "expo-router";
import { Fragment } from "react";
import { ScrollView } from "react-native";

import { AppSection } from "@/components/app/app-section";
import { Separator } from "@/components/ui/separator";
import { Text } from "@/components/ui/text";
import { useModeEditor } from "@/features/modes/mode-editor-state";
import {
  modelDisplayName,
  selectedRoute,
  transcriptionModelDetail,
} from "@/features/modes/model-catalog";
import { useModes } from "@/features/modes/mode-provider";
import { PickerOption } from "@/features/modes/picker-option";
import { ProviderIcon } from "@/features/modes/provider-icon";

export default function ModelPickerScreen() {
  const router = useRouter();
  const editor = useModeEditor();
  const { catalog } = useModes();
  const groups = [
    {
      models:
        catalog?.transcriptionModels.filter(
          (model) => model.runtime === "cloud",
        ) ?? [],
      title: "Cloud",
    },
    {
      models:
        catalog?.transcriptionModels.filter(
          (model) => model.runtime === "local",
        ) ?? [],
      title: "On device",
    },
  ];
  return (
    <ScrollView
      className="bg-background flex-1"
      contentContainerClassName="gap-5 px-[18px] pt-3 pb-10"
    >
      {groups.map((group) => (
        <AppSection
          contentClassName="px-0"
          key={group.title}
          title={group.title}
        >
          {group.models.map((model, index) => (
            <Fragment key={model.id}>
              {index > 0 ? <Separator className="mx-4 w-auto" /> : null}
              <PickerOption
                detail={transcriptionModelDetail(model)}
                grouped
                label={modelDisplayName(model)}
                leading={<ProviderIcon provider={model.provider} />}
                live={Boolean(model.realtime)}
                onPress={() => {
                  const route = selectedRoute(model);
                  editor.patch({
                    asrModelId: model.id,
                    identifySpeakers: route?.supportsDiarization
                      ? (editor.draft?.identifySpeakers ?? false)
                      : false,
                    language: route?.supportsAutomaticLanguage
                      ? null
                      : (route?.supportedLanguages[0] ?? null),
                    realtimeEnabled: Boolean(model.realtime),
                  });
                  router.back();
                }}
                selected={editor.draft?.asrModelId === model.id}
              />
            </Fragment>
          ))}
        </AppSection>
      ))}
      <Text className="text-muted-foreground px-1 text-xs leading-4">
        Cloud WER is provider-published: Deepgram uses mixed-domain audio and
        Voxtral uses English FLEURS at 240 ms. Local WER uses FluidAudio
        LibriSpeech test-clean. Results are not directly comparable.
      </Text>
    </ScrollView>
  );
}
