import { useRouter } from "expo-router";
import { ScrollView } from "react-native";

import { ModeRow } from "@/features/modes/mode-row";
import { useModes } from "@/features/modes/mode-provider";

export default function ModePickerScreen() {
  const router = useRouter();
  const modes = useModes();
  return (
    <ScrollView
      className="bg-background flex-1"
      contentContainerClassName="gap-3 px-[18px] pt-3 pb-10"
    >
      {modes.modes.map((mode) => (
        <ModeRow
          accessibilityLabel={`Use ${mode.name}`}
          key={mode.id}
          mode={mode}
          onPress={() => {
            void modes.activateMode(mode.id).then(() => router.back());
          }}
        />
      ))}
    </ScrollView>
  );
}
