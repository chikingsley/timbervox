import Constants from "expo-constants";
import { SymbolView } from "expo-symbols";
import { useRouter } from "expo-router";
import { Pressable, View } from "react-native";

import { AppScreen } from "@/components/app/app-screen";
import { AppSection } from "@/components/app/app-section";
import { Separator } from "@/components/ui/separator";
import { Text } from "@/components/ui/text";
import { useDictationSession } from "@/features/dictation/dictation-session";
import {
  modelDisplayName,
  selectedTranscriptionModel,
} from "@/features/modes/model-catalog";
import { useModes } from "@/features/modes/mode-provider";
import { useSetupState } from "@/features/setup/setup-state";
import { cn } from "@/lib/utils";

export default function SettingsScreen() {
  const router = useRouter();
  const session = useDictationSession();
  const modes = useModes();
  const setup = useSetupState();
  const activeModel =
    modes.activeMode && modes.catalog
      ? selectedTranscriptionModel(modes.catalog, modes.activeMode.asrModelId)
      : undefined;
  const restartSetup = () => {
    setup.restart();
    router.dismissAll();
    router.replace("/");
  };

  return (
    <AppScreen scroll>
      <AppSection title="Keyboard">
        <StatusRow
          label="TimberVox keyboard"
          verified={setup.keyboardVerified}
        />
        <Separator />
        <StatusRow label="Full Access" verified={setup.keyboardVerified} />
        <Pressable
          className="min-h-[54px] flex-row items-center justify-between"
          onPress={setup.openSettings}
        >
          <Text className="text-primary text-[15px] font-bold">
            Open iPhone Settings
          </Text>
          <SymbolView name="arrow.up.right" size={14} tintColor="#91a8ff" />
        </Pressable>
      </AppSection>

      <AppSection className="mt-1" title="Dictation">
        <ValueRow
          label="Mode"
          value={modes.activeMode?.name ?? "Voice to Text"}
        />
        <Separator />
        <ValueRow
          label="Model"
          value={activeModel ? modelDisplayName(activeModel) : "Loading…"}
        />
        <Separator />
        <ValueRow
          label="Background session"
          value={session.sessionActive ? "Ready" : "Off"}
        />
        {session.sessionActive ? (
          <Pressable
            className="min-h-[54px] flex-row items-center justify-between"
            onPress={session.endSession}
          >
            <Text className="text-destructive text-[15px] font-bold">
              End background session
            </Text>
          </Pressable>
        ) : null}
      </AppSection>

      <AppSection className="mt-1" title="Setup">
        <Pressable
          className="min-h-[54px] flex-row items-center justify-between"
          onPress={restartSetup}
        >
          <Text className="text-primary text-[15px] font-bold">
            Run setup again
          </Text>
          <SymbolView name="chevron.right" size={14} tintColor="#7f8796" />
        </Pressable>
      </AppSection>

      <Text className="text-muted-foreground mt-3 text-center text-xs">
        TimberVox {Constants.expoConfig?.version ?? "1.0.0"} (
        {Constants.expoConfig?.ios?.buildNumber ?? "—"})
      </Text>
    </AppScreen>
  );
}

function StatusRow({ label, verified }: { label: string; verified: boolean }) {
  return (
    <View className="min-h-[58px] flex-row items-center justify-between gap-3">
      <Text className="font-semibold">{label}</Text>
      <View className="flex-row items-center gap-2">
        <View
          className={cn(
            "bg-muted-foreground size-2 rounded-full",
            verified && "bg-success",
          )}
        />
        <Text
          className={cn(
            "text-muted-foreground text-sm",
            verified && "text-success",
          )}
        >
          {verified ? "Verified" : "Not verified"}
        </Text>
      </View>
    </View>
  );
}

function ValueRow({ label, value }: { label: string; value: string }) {
  return (
    <View className="min-h-[58px] flex-row items-center justify-between gap-3">
      <Text className="font-semibold">{label}</Text>
      <Text className="text-muted-foreground text-sm">{value}</Text>
    </View>
  );
}
