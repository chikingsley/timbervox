import { ExtensionStorage } from '@bacons/apple-targets';
import {
  requestRecordingPermissionsAsync,
  setAudioModeAsync,
  useAudioStream,
  type AudioStreamBuffer,
} from 'expo-audio';
import * as Linking from 'expo-linking';
import * as SecureStore from 'expo-secure-store';
import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

const APP_GROUP = 'group.com.chiejimofor.timbervox';
const API_KEY_STORAGE_KEY = 'timbervox.api-key';
const REALTIME_MODEL = 'mistral-voxtral-mini-latest';
const storage = new ExtensionStorage(APP_GROUP);

type SessionStage = 'idle' | 'ready' | 'connecting' | 'recording' | 'processing';

type DictationSessionValue = {
  endSession: () => Promise<void>;
  error: string | null;
  loadApiKey: () => Promise<string>;
  partialTranscript: string;
  recording: boolean;
  saveApiKey: (value: string) => Promise<void>;
  sessionActive: boolean;
  startSession: () => Promise<void>;
  stateLabel: string;
};

const DictationSessionContext = createContext<DictationSessionValue | null>(null);

export function DictationSessionProvider({ children }: PropsWithChildren) {
  const [stage, setStage] = useState<SessionStage>('idle');
  const [error, setError] = useState<string | null>(null);
  const [partialTranscript, setPartialTranscript] = useState('');
  const apiKeyRef = useRef('');
  const socketRef = useRef<WebSocket | null>(null);
  const queuedAudioRef = useRef<ArrayBuffer[]>([]);
  const partialAccumulatorRef = useRef('');
  const lastRequestRevisionRef = useRef(readNumber('requestRevision'));
  const closingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const publishTranscript = useCallback((text: string) => {
    const clean = text.trim();
    if (!clean) return;
    storage.set('pendingTranscript', clean);
    storage.set('partialTranscript', '');
    storage.set('transcriptRevision', readNumber('transcriptRevision') + 1);
    storage.set('recordingRequested', 0);
    setPartialTranscript(clean);
    setStage('ready');
  }, []);

  const finishSocket = useCallback(() => {
    const socket = socketRef.current;
    if (!socket) return;
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({ type: 'close' }));
      setStage('processing');
      if (closingTimerRef.current) clearTimeout(closingTimerRef.current);
      closingTimerRef.current = setTimeout(() => {
        socket.close();
        socketRef.current = null;
        storage.set('recordingRequested', 0);
        setStage('ready');
      }, 5_000);
    } else if (socket.readyState === WebSocket.CONNECTING) {
      socket.close();
      socketRef.current = null;
      queuedAudioRef.current = [];
      storage.set('recordingRequested', 0);
      setStage('ready');
    }
  }, []);

  const beginRealtime = useCallback(async () => {
    if (socketRef.current) return;
    let apiKey = apiKeyRef.current;
    if (!apiKey) {
      try {
        apiKey = (await SecureStore.getItemAsync(API_KEY_STORAGE_KEY)) ?? '';
        apiKeyRef.current = apiKey;
      } catch {
        // Unsigned Simulator builds do not receive the Keychain entitlement.
      }
    }
    if (!apiKey) {
      setError('Save a TimberVox API key before dictating.');
      queuedAudioRef.current = [];
      storage.set('recordingRequested', 0);
      return;
    }

    setError(null);
    setPartialTranscript('');
    partialAccumulatorRef.current = '';
    storage.set('partialTranscript', '');
    setStage('connecting');
    const params = new URLSearchParams({
      model: REALTIME_MODEL,
      encoding: 'linear16',
      sample_rate: '16000',
      channels: '1',
      interim_results: 'true',
      punctuate: 'true',
      dictation: 'true',
      target_streaming_delay_ms: '200',
    });
    const url = `wss://timbervox.peacockery.studio/v1/realtime?${params.toString()}`;
    const WebSocketWithHeaders = WebSocket as unknown as new (
      url: string,
      protocols: string[],
      options: { headers: Record<string, string> },
    ) => WebSocket;
    const socket = new WebSocketWithHeaders(url, [], {
      headers: { Authorization: `Bearer ${apiKey}` },
    });
    socket.binaryType = 'arraybuffer';
    socketRef.current = socket;

    socket.onopen = () => {
      setStage('recording');
      for (const chunk of queuedAudioRef.current) socket.send(chunk);
      queuedAudioRef.current = [];
    };
    socket.onmessage = (event) => {
      if (typeof event.data !== 'string') return;
      const message = parseEvent(event.data);
      if (!message) return;
      if (message.error) {
        setError(message.error);
        return;
      }
      if (message.delta !== undefined) {
        partialAccumulatorRef.current += message.delta;
        setPartialTranscript(partialAccumulatorRef.current);
        storage.set('partialTranscript', partialAccumulatorRef.current);
      } else if (message.partial !== undefined && !partialAccumulatorRef.current) {
        partialAccumulatorRef.current = message.partial;
        setPartialTranscript(message.partial);
        storage.set('partialTranscript', message.partial);
      }
      if (message.final !== undefined) publishTranscript(message.final);
    };
    socket.onerror = () => {
      setError('The realtime transcription connection failed.');
      storage.set('recordingRequested', 0);
      setStage('ready');
    };
    socket.onclose = () => {
      socketRef.current = null;
      if (closingTimerRef.current) clearTimeout(closingTimerRef.current);
      closingTimerRef.current = null;
      storage.set('recordingRequested', 0);
      setStage((current) => (current === 'idle' ? current : 'ready'));
    };
  }, [publishTranscript]);

  const handleAudioBuffer = useCallback(
    (buffer: AudioStreamBuffer) => {
      const revision = readNumber('requestRevision');
      if (revision !== lastRequestRevisionRef.current) {
        lastRequestRevisionRef.current = revision;
        if (readBoolean('recordingRequested')) {
          void beginRealtime();
        } else {
          finishSocket();
        }
      }

      if (!readBoolean('recordingRequested')) return;
      const socket = socketRef.current;
      if (socket?.readyState === WebSocket.OPEN) {
        socket.send(buffer.data);
      } else if (queuedAudioRef.current.length < 20) {
        queuedAudioRef.current.push(buffer.data);
      }
    },
    [beginRealtime, finishSocket],
  );

  const { stream } = useAudioStream({
    sampleRate: 16_000,
    channels: 1,
    encoding: 'int16',
    onBuffer: handleAudioBuffer,
  });

  const startSession = useCallback(async () => {
    const permission = await requestRecordingPermissionsAsync();
    if (!permission.granted) {
      setError('Microphone access is required.');
      return;
    }
    await setAudioModeAsync({
      allowsRecording: true,
      allowsBackgroundRecording: true,
      playsInSilentMode: true,
    });
    await stream.start();
    storage.set('sessionActive', 1);
    storage.set('recordingRequested', 0);
    setError(null);
    setStage('ready');
  }, [stream]);

  const endSession = useCallback(async () => {
    finishSocket();
    stream.stop();
    storage.set('sessionActive', 0);
    storage.set('recordingRequested', 0);
    storage.set('partialTranscript', '');
    setPartialTranscript('');
    setStage('idle');
  }, [finishSocket, stream]);

  useEffect(() => {
    const handleURL = ({ url }: { url: string }) => {
      const parsed = Linking.parse(url);
      if (parsed.hostname === 'session' || parsed.path === 'session') void startSession();
    };
    const subscription = Linking.addEventListener('url', handleURL);
    void Linking.getInitialURL().then((url) => url && handleURL({ url }));
    return () => subscription.remove();
  }, [startSession]);

  useEffect(() => {
    storage.set('sessionActive', 0);
    storage.set('recordingRequested', 0);
    return () => {
      storage.set('sessionActive', 0);
      storage.set('recordingRequested', 0);
    };
  }, []);

  const loadApiKey = useCallback(async () => {
    try {
      apiKeyRef.current = (await SecureStore.getItemAsync(API_KEY_STORAGE_KEY)) ?? '';
    } catch {
      // Keep the screen usable in an unsigned Simulator build.
    }
    return apiKeyRef.current;
  }, []);
  const saveApiKey = useCallback(async (value: string) => {
    apiKeyRef.current = value;
    try {
      if (value) await SecureStore.setItemAsync(API_KEY_STORAGE_KEY, value);
      else await SecureStore.deleteItemAsync(API_KEY_STORAGE_KEY);
    } catch (secureStoreError) {
      if (!__DEV__) throw secureStoreError;
    }
  }, []);

  const value = useMemo<DictationSessionValue>(
    () => ({
      endSession,
      error,
      loadApiKey,
      partialTranscript,
      recording: stage === 'recording' || stage === 'connecting',
      saveApiKey,
      sessionActive: stage !== 'idle',
      startSession,
      stateLabel: stageLabel(stage),
    }),
    [endSession, error, loadApiKey, partialTranscript, saveApiKey, stage, startSession],
  );

  return (
    <DictationSessionContext.Provider value={value}>{children}</DictationSessionContext.Provider>
  );
}

export function useDictationSession() {
  const value = useContext(DictationSessionContext);
  if (!value) throw new Error('useDictationSession must be used inside DictationSessionProvider');
  return value;
}

function readNumber(key: string) {
  return Number(storage.get(key) ?? 0);
}

function readBoolean(key: string) {
  return readNumber(key) > 0;
}

function stageLabel(stage: SessionStage) {
  switch (stage) {
    case 'idle':
      return 'Session off';
    case 'ready':
      return 'Ready in background';
    case 'connecting':
      return 'Connecting to Voxtral…';
    case 'recording':
      return 'Listening…';
    case 'processing':
      return 'Finishing transcript…';
  }
}

function parseEvent(
  raw: string,
): { delta?: string; error?: string; final?: string; partial?: string } | null {
  try {
    const event = JSON.parse(raw) as Record<string, unknown>;
    if (event.error) {
      return { error: typeof event.error === 'string' ? event.error : JSON.stringify(event.error) };
    }
    const type = typeof event.type === 'string' ? event.type : '';
    const text = typeof event.text === 'string' ? event.text : '';
    if (type === 'transcription.done') return { final: text };
    if (type === 'transcription.text.delta') return { delta: text };
    if (type === 'transcription.segment') return { partial: text };
    return null;
  } catch {
    return null;
  }
}
