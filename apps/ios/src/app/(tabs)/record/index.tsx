import { SymbolView } from "expo-symbols";
import { useRouter } from "expo-router";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { AppBottomActionBar } from "@/components/app/app-bottom-action-bar";
import { AppScreen } from "@/components/app/app-screen";
import { RecordingControl } from "@/components/app/recording-control";
import { useDictationSession } from "@/features/dictation/dictation-session";
import { useModes } from "@/features/modes/mode-provider";

export default function RecordScreen() {
  const router = useRouter();
  const session = useDictationSession();
  const { activeMode } = useModes();

  return (
    <View className="bg-background flex-1">
      <AppScreen className="px-5" edges={["top", "left", "right"]}>
        <Pressable
          accessibilityLabel="Choose active mode"
          onPress={() => router.push("/mode-picker")}
          style={styles.modePicker}
        >
          <SymbolView
            name={(activeMode?.iconKey ?? "person.wave.2.fill") as never}
            size={24}
            tintColor="#ffffff"
          />
          <Text style={styles.modeText}>
            {activeMode?.name ?? "Voice to Text"}
          </Text>
          <SymbolView name="chevron.right" size={14} tintColor="#707785" />
        </Pressable>

        <View style={styles.recorderArea}>
          <Text style={styles.recorderState}>{session.stateLabel}</Text>
          {session.partialTranscript ? (
            <Text numberOfLines={6} style={styles.liveTranscript}>
              {session.partialTranscript}
            </Text>
          ) : (
            <Text style={styles.recorderHint}>
              Tap Dictate to speak here, or leave the session ready and use the
              TimberVox keyboard.
            </Text>
          )}
          {session.error ? (
            <Text style={styles.error}>{session.error}</Text>
          ) : null}
        </View>

        {session.lastTranscript ? (
          <View style={styles.resultCard}>
            <Text style={styles.cardLabel}>LATEST</Text>
            <Text numberOfLines={4} style={styles.resultText}>
              {session.lastTranscript}
            </Text>
          </View>
        ) : null}
      </AppScreen>

      <AppBottomActionBar>
        <RecordingControl
          onPress={
            session.recording ? session.stopDictation : session.startDictation
          }
          recording={session.recording}
        />
      </AppBottomActionBar>
    </View>
  );
}

const styles = StyleSheet.create({
  modePicker: {
    alignSelf: "center",
    flexDirection: "row",
    gap: 10,
    alignItems: "center",
    marginTop: 18,
    paddingHorizontal: 18,
    height: 50,
    borderRadius: 25,
    backgroundColor: "#15181f",
  },
  modeText: { color: "#ffffff", fontSize: 20, fontWeight: "600" },
  recorderArea: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 14,
    gap: 14,
  },
  recorderState: { color: "#cbd1dc", fontSize: 15, fontWeight: "700" },
  recorderHint: {
    color: "#6f7683",
    fontSize: 15,
    lineHeight: 21,
    textAlign: "center",
    maxWidth: 290,
  },
  liveTranscript: {
    color: "#f4f6fb",
    fontSize: 22,
    lineHeight: 30,
    textAlign: "center",
  },
  error: { color: "#ff767c", fontSize: 14, textAlign: "center" },
  resultCard: {
    borderRadius: 18,
    padding: 16,
    backgroundColor: "#151820",
    gap: 7,
  },
  cardLabel: {
    color: "#6f93ff",
    fontSize: 10,
    fontWeight: "800",
    letterSpacing: 1.1,
  },
  resultText: { color: "#e7eaf1", fontSize: 15, lineHeight: 21 },
});
