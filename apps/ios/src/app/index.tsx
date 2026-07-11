import { useEffect, useState } from 'react';
import {
  Alert,
  Button,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useDictationSession } from '@/features/dictation/dictation-session';

export default function HomeScreen() {
  const session = useDictationSession();
  const { loadApiKey } = session;
  const [apiKey, setApiKey] = useState('');

  useEffect(() => {
    loadApiKey().then(setApiKey);
  }, [loadApiKey]);

  const saveApiKey = async () => {
    await session.saveApiKey(apiKey.trim());
    Alert.alert('Saved', 'The API key is stored in the iOS Keychain on this device.');
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.flex}>
        <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
          <View style={styles.header}>
            <View style={styles.mark}>
              <Text style={styles.markText}>T</Text>
            </View>
            <View style={styles.flex}>
              <Text style={styles.title}>TimberVox</Text>
              <Text style={styles.subtitle}>Realtime voice keyboard</Text>
            </View>
            <StatusDot active={session.sessionActive} />
          </View>

          <View style={[styles.card, session.recording && styles.recordingCard]}>
            <Text style={styles.eyebrow}>DICTATION SESSION</Text>
            <Text style={styles.stateTitle}>{session.stateLabel}</Text>
            <Text style={styles.detail}>
              {session.sessionActive
                ? 'The microphone session stays available while you type in other apps.'
                : 'Start once, return to your app, then use the TimberVox keyboard microphone.'}
            </Text>
            {session.partialTranscript ? (
              <View style={styles.transcriptBox}>
                <Text style={styles.transcript}>{session.partialTranscript}</Text>
              </View>
            ) : null}
            {session.error ? <Text style={styles.error}>{session.error}</Text> : null}
            <Pressable
              onPress={session.sessionActive ? session.endSession : session.startSession}
              style={({ pressed }) => [
                styles.primaryButton,
                session.sessionActive && styles.stopButton,
                pressed && styles.pressed,
              ]}>
              <Text style={styles.primaryButtonText}>
                {session.sessionActive ? 'End session' : 'Start session'}
              </Text>
            </Pressable>
          </View>

          <View style={styles.card}>
            <Text style={styles.eyebrow}>CLOUD</Text>
            <Text style={styles.sectionTitle}>Voxtral realtime</Text>
            <Text style={styles.detail}>
              Mistral Voxtral Mini streams 16 kHz mono PCM through the TimberVox Worker.
            </Text>
            <TextInput
              value={apiKey}
              onChangeText={setApiKey}
              autoCapitalize="none"
              autoCorrect={false}
              secureTextEntry
              placeholder="TimberVox API key"
              style={styles.input}
            />
            <Button title="Save API key" onPress={saveApiKey} />
          </View>

          <View style={styles.card}>
            <Text style={styles.eyebrow}>SETUP</Text>
            <Text style={styles.sectionTitle}>Enable the keyboard</Text>
            <Step number="1" text="Open Settings → General → Keyboard → Keyboards." />
            <Step number="2" text="Add TimberVox and enable Full Access for the voice bridge." />
            <Step number="3" text="Start a session here, return to any text field, and use the globe key." />
          </View>

          <Text style={styles.footnote}>
            Debug builds can open TimberVox directly from the keyboard. Release builds use the
            session/Shortcut path required for distribution.
          </Text>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function StatusDot({ active }: { active: boolean }) {
  return <View style={[styles.statusDot, active && styles.statusDotActive]} />;
}

function Step({ number, text }: { number: string; text: string }) {
  return (
    <View style={styles.step}>
      <View style={styles.stepNumber}>
        <Text style={styles.stepNumberText}>{number}</Text>
      </View>
      <Text style={styles.stepText}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  safeArea: { flex: 1, backgroundColor: '#0b0d12' },
  content: { padding: 20, paddingBottom: 60, gap: 16 },
  header: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 8 },
  mark: {
    width: 44,
    height: 44,
    borderRadius: 13,
    backgroundColor: '#4f7cff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  markText: { color: 'white', fontSize: 23, fontWeight: '800' },
  title: { color: 'white', fontSize: 25, fontWeight: '700' },
  subtitle: { color: '#939aaa', fontSize: 14, marginTop: 1 },
  statusDot: { width: 11, height: 11, borderRadius: 6, backgroundColor: '#3b404b' },
  statusDotActive: { backgroundColor: '#34c98f' },
  card: {
    borderRadius: 20,
    padding: 20,
    backgroundColor: '#151820',
    borderWidth: 1,
    borderColor: '#222734',
    gap: 12,
  },
  recordingCard: { borderColor: '#ff5d64' },
  eyebrow: { color: '#6f93ff', fontSize: 11, fontWeight: '800', letterSpacing: 1.2 },
  stateTitle: { color: 'white', fontSize: 27, fontWeight: '700' },
  sectionTitle: { color: 'white', fontSize: 20, fontWeight: '700' },
  detail: { color: '#a5acbb', fontSize: 15, lineHeight: 21 },
  transcriptBox: { backgroundColor: '#0d1016', padding: 14, borderRadius: 12 },
  transcript: { color: '#e9ecf4', fontSize: 16, lineHeight: 22 },
  error: { color: '#ff7b80', fontSize: 14 },
  primaryButton: {
    backgroundColor: '#4f7cff',
    minHeight: 50,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 4,
  },
  stopButton: { backgroundColor: '#303645' },
  primaryButtonText: { color: 'white', fontSize: 16, fontWeight: '700' },
  pressed: { opacity: 0.78 },
  input: {
    minHeight: 48,
    borderRadius: 12,
    paddingHorizontal: 14,
    backgroundColor: '#0d1016',
    color: 'white',
    borderWidth: 1,
    borderColor: '#2b3140',
  },
  step: { flexDirection: 'row', alignItems: 'flex-start', gap: 12 },
  stepNumber: {
    width: 25,
    height: 25,
    borderRadius: 13,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#252b38',
  },
  stepNumberText: { color: '#8da7ff', fontWeight: '800', fontSize: 12 },
  stepText: { color: '#b1b7c4', flex: 1, fontSize: 14, lineHeight: 20 },
  footnote: { color: '#656c79', fontSize: 12, lineHeight: 17, paddingHorizontal: 4 },
});
