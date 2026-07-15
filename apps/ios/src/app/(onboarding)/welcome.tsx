import { SymbolView } from "expo-symbols";
import { useRouter } from "expo-router";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { useDictationSession } from "@/features/dictation/dictation-session";
import { useSetupState } from "@/features/setup/setup-state";

export default function WelcomeScreen() {
  const router = useRouter();
  const setup = useSetupState();
  const session = useDictationSession();
  const finish = () => {
    setup.complete();
    router.replace("/record");
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.welcomeMark}>
          <SymbolView name="waveform" size={34} tintColor="#ffffff" />
        </View>
        <Text style={styles.title}>Set up TimberVox</Text>
        <Text style={styles.subtitle}>
          Enable the microphone and keyboard, then complete one real dictation.
        </Text>

        <SetupCard
          action={session.sessionActive ? undefined : session.startSession}
          actionLabel="Allow Microphone"
          complete={session.sessionActive}
          detail="TimberVox records only while a dictation session is active."
          number="1"
          title="Microphone"
        />
        <SetupCard
          action={setup.openSettings}
          actionLabel="Open iPhone Settings"
          complete={setup.keyboardVerified}
          detail="Open Keyboards, add TimberVox, and enable Full Access. Then activate it once in any text field."
          number="2"
          title="Keyboard and Full Access"
        />

        <Pressable
          disabled={!session.sessionActive || !setup.keyboardVerified}
          onPress={finish}
          style={({ pressed }) => [
            styles.primaryButton,
            (!session.sessionActive || !setup.keyboardVerified) &&
              styles.disabledButton,
            pressed && styles.pressed,
          ]}
        >
          <Text style={styles.primaryButtonText}>Finish setup</Text>
        </Pressable>
        <Pressable onPress={finish} style={styles.secondaryButton}>
          <Text style={styles.secondaryButtonText}>
            Continue with the app recorder
          </Text>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

function SetupCard({
  action,
  actionLabel,
  complete,
  detail,
  number,
  title,
}: {
  action?: () => void | Promise<void>;
  actionLabel: string;
  complete: boolean;
  detail: string;
  number: string;
  title: string;
}) {
  return (
    <View style={styles.setupCard}>
      <View style={styles.setupCardHeader}>
        <View style={[styles.stepBadge, complete && styles.stepBadgeComplete]}>
          <Text style={styles.stepBadgeText}>{complete ? "✓" : number}</Text>
        </View>
        <Text style={styles.setupTitle}>{title}</Text>
      </View>
      <Text style={styles.setupDetail}>{detail}</Text>
      {action ? (
        <Pressable onPress={action} style={styles.setupAction}>
          <Text style={styles.setupActionText}>
            {complete ? "Verified" : actionLabel}
          </Text>
          {!complete ? (
            <SymbolView name="arrow.up.right" size={13} tintColor="#8ea8ff" />
          ) : null}
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: "#0b0d12", paddingHorizontal: 20 },
  content: { paddingTop: 32, paddingBottom: 40, gap: 14 },
  welcomeMark: {
    width: 62,
    height: 62,
    borderRadius: 20,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#4f7cff",
    marginBottom: 8,
  },
  title: { color: "#ffffff", fontSize: 32, fontWeight: "800" },
  subtitle: {
    color: "#8f96a4",
    fontSize: 16,
    lineHeight: 23,
    marginBottom: 16,
  },
  setupCard: {
    borderRadius: 20,
    padding: 18,
    backgroundColor: "#151820",
    borderWidth: 1,
    borderColor: "#242937",
    gap: 12,
  },
  setupCardHeader: { flexDirection: "row", alignItems: "center", gap: 12 },
  stepBadge: {
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#293043",
  },
  stepBadgeComplete: { backgroundColor: "#19865c" },
  stepBadgeText: { color: "#ffffff", fontSize: 13, fontWeight: "800" },
  setupTitle: { color: "#ffffff", fontSize: 18, fontWeight: "700" },
  setupDetail: { color: "#9da4b2", fontSize: 14, lineHeight: 20 },
  setupAction: {
    minHeight: 44,
    paddingHorizontal: 14,
    borderRadius: 12,
    backgroundColor: "#202638",
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  setupActionText: { color: "#a9bbff", fontSize: 14, fontWeight: "700" },
  primaryButton: {
    minHeight: 52,
    borderRadius: 15,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#4f7cff",
    marginTop: 10,
  },
  disabledButton: { opacity: 0.35 },
  primaryButtonText: { color: "#ffffff", fontSize: 16, fontWeight: "800" },
  secondaryButton: {
    minHeight: 44,
    alignItems: "center",
    justifyContent: "center",
  },
  secondaryButtonText: { color: "#858d9c", fontSize: 14, fontWeight: "600" },
  pressed: { opacity: 0.72 },
});
