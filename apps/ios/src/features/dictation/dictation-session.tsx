import { ExtensionStorage } from "@bacons/apple-targets";
import {
  requestRecordingPermissionsAsync,
  setAudioModeAsync,
  useAudioStream,
  type AudioStreamBuffer,
} from "expo-audio";
import Constants from "expo-constants";
import * as Linking from "expo-linking";
import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";

import { useHistory } from "@/features/history/history-store";

const APP_GROUP = "group.com.chiejimofor.timbervox";
const REALTIME_MODEL = "mistral-voxtral-mini-transcribe-realtime-2602";
const storage = new ExtensionStorage(APP_GROUP);
const buildCredential = readBuildCredential();

type SessionStage =
  "idle" | "ready" | "connecting" | "recording" | "processing";

type DictationSessionValue = {
  endSession: () => Promise<void>;
  error: string | null;
  lastTranscript: string;
  partialTranscript: string;
  recording: boolean;
  sessionActive: boolean;
  startDictation: () => Promise<void>;
  startSession: () => Promise<void>;
  stateLabel: string;
  stopDictation: () => void;
};

const DictationSessionContext = createContext<DictationSessionValue | null>(
  null,
);

export function DictationSessionProvider({ children }: PropsWithChildren) {
  const history = useHistory();
  const [stage, setStage] = useState<SessionStage>("idle");
  const [error, setError] = useState<string | null>(null);
  const [partialTranscript, setPartialTranscript] = useState("");
  const [lastTranscript, setLastTranscript] = useState("");
  const socketRef = useRef<WebSocket | null>(null);
  const queuedAudioRef = useRef<ArrayBuffer[]>([]);
  const capturedAudioRef = useRef<ArrayBuffer[]>([]);
  const partialAccumulatorRef = useRef("");
  const recordingOriginRef = useRef<"app" | "keyboard">("keyboard");
  const recordingStartedAtRef = useRef(0);
  const sessionActiveRef = useRef(false);
  const lastRequestRevisionRef = useRef(readNumber("requestRevision"));
  const closingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const publishTranscript = useCallback(
    async (text: string) => {
      const clean = text.trim();
      if (!clean) return;
      storage.set("pendingTranscript", clean);
      storage.set("partialTranscript", "");
      storage.set("transcriptRevision", readNumber("transcriptRevision") + 1);
      storage.set("recordingRequested", 0);
      setPartialTranscript("");
      setLastTranscript(clean);
      await history.add({
        audioChunks: capturedAudioRef.current,
        durationMs: Math.max(0, Date.now() - recordingStartedAtRef.current),
        model: REALTIME_MODEL,
        source: recordingOriginRef.current,
        text: clean,
      });
      capturedAudioRef.current = [];
      setStage("ready");
    },
    [history],
  );

  const finishSocket = useCallback(() => {
    const socket = socketRef.current;
    if (!socket) return;
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({ type: "close" }));
      setStage("processing");
      if (closingTimerRef.current) clearTimeout(closingTimerRef.current);
      closingTimerRef.current = setTimeout(() => {
        socket.close();
        socketRef.current = null;
        storage.set("recordingRequested", 0);
        setStage("ready");
      }, 5_000);
    } else if (socket.readyState === WebSocket.CONNECTING) {
      socket.close();
      socketRef.current = null;
      queuedAudioRef.current = [];
      storage.set("recordingRequested", 0);
      setStage("ready");
    }
  }, []);

  const beginRealtime = useCallback(
    async (origin: "app" | "keyboard" = "keyboard") => {
      if (socketRef.current) return;
      if (!buildCredential) {
        setError("This build is missing its TimberVox API credential.");
        queuedAudioRef.current = [];
        storage.set("recordingRequested", 0);
        return;
      }

      setError(null);
      setPartialTranscript("");
      partialAccumulatorRef.current = "";
      capturedAudioRef.current = [];
      recordingOriginRef.current = origin;
      recordingStartedAtRef.current = Date.now();
      storage.set("partialTranscript", "");
      setStage("connecting");
      const params = new URLSearchParams({
        model: REALTIME_MODEL,
        encoding: "linear16",
        sample_rate: "16000",
        channels: "1",
        interim_results: "true",
        punctuate: "true",
        dictation: "true",
        target_streaming_delay_ms: "200",
      });
      const url = `wss://timbervox.peacockery.studio/v1/realtime?${params.toString()}`;
      const WebSocketWithHeaders = WebSocket as unknown as new (
        url: string,
        protocols: string[],
        options: { headers: Record<string, string> },
      ) => WebSocket;
      const socket = new WebSocketWithHeaders(url, [], {
        headers: { Authorization: `Bearer ${buildCredential}` },
      });
      socket.binaryType = "arraybuffer";
      socketRef.current = socket;

      socket.onopen = () => {
        setStage("recording");
        for (const chunk of queuedAudioRef.current) socket.send(chunk);
        queuedAudioRef.current = [];
      };
      socket.onmessage = (event) => {
        if (typeof event.data !== "string") return;
        const message = parseEvent(event.data);
        if (!message) return;
        if (message.error) {
          setError(message.error);
          return;
        }
        if (message.delta !== undefined) {
          partialAccumulatorRef.current += message.delta;
          setPartialTranscript(partialAccumulatorRef.current);
          storage.set("partialTranscript", partialAccumulatorRef.current);
        } else if (
          message.partial !== undefined &&
          !partialAccumulatorRef.current
        ) {
          partialAccumulatorRef.current = message.partial;
          setPartialTranscript(message.partial);
          storage.set("partialTranscript", message.partial);
        }
        if (message.final !== undefined) void publishTranscript(message.final);
      };
      socket.onerror = () => {
        setError("The realtime transcription connection failed.");
        storage.set("recordingRequested", 0);
        setStage("ready");
      };
      socket.onclose = () => {
        socketRef.current = null;
        if (closingTimerRef.current) clearTimeout(closingTimerRef.current);
        closingTimerRef.current = null;
        storage.set("recordingRequested", 0);
        setStage((current) => (current === "idle" ? current : "ready"));
      };
    },
    [publishTranscript],
  );

  const handleAudioBuffer = useCallback(
    (buffer: AudioStreamBuffer) => {
      const revision = readNumber("requestRevision");
      if (revision !== lastRequestRevisionRef.current) {
        lastRequestRevisionRef.current = revision;
        if (readBoolean("recordingRequested")) {
          void beginRealtime("keyboard");
        } else {
          finishSocket();
        }
      }

      if (!readBoolean("recordingRequested")) return;
      capturedAudioRef.current.push(buffer.data.slice(0));
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
    encoding: "int16",
    onBuffer: handleAudioBuffer,
  });

  const startSession = useCallback(async () => {
    const permission = await requestRecordingPermissionsAsync();
    if (!permission.granted) {
      setError("Microphone access is required.");
      return;
    }
    await setAudioModeAsync({
      allowsRecording: true,
      allowsBackgroundRecording: true,
      playsInSilentMode: true,
    });
    await stream.start();
    storage.set("sessionActive", 1);
    storage.set("recordingRequested", 0);
    setError(null);
    sessionActiveRef.current = true;
    setStage("ready");
  }, [stream]);

  const startDictation = useCallback(async () => {
    if (!sessionActiveRef.current) await startSession();
    if (!sessionActiveRef.current) return;
    storage.set("recordingRequested", 1);
    storage.set("requestRevision", readNumber("requestRevision") + 1);
    await beginRealtime("app");
  }, [beginRealtime, startSession]);

  const stopDictation = useCallback(() => {
    storage.set("recordingRequested", 0);
    storage.set("requestRevision", readNumber("requestRevision") + 1);
    finishSocket();
  }, [finishSocket]);

  const endSession = useCallback(async () => {
    finishSocket();
    stream.stop();
    storage.set("sessionActive", 0);
    storage.set("recordingRequested", 0);
    storage.set("partialTranscript", "");
    sessionActiveRef.current = false;
    setPartialTranscript("");
    setStage("idle");
  }, [finishSocket, stream]);

  useEffect(() => {
    const handleURL = ({ url }: { url: string }) => {
      const parsed = Linking.parse(url);
      if (parsed.hostname === "session" || parsed.path === "session")
        void startSession();
    };
    const subscription = Linking.addEventListener("url", handleURL);
    void Linking.getInitialURL().then((url) => url && handleURL({ url }));
    return () => subscription.remove();
  }, [startSession]);

  useEffect(() => {
    storage.set("sessionActive", 0);
    storage.set("recordingRequested", 0);
    return () => {
      storage.set("sessionActive", 0);
      storage.set("recordingRequested", 0);
    };
  }, []);

  const value = useMemo<DictationSessionValue>(
    () => ({
      endSession,
      error,
      lastTranscript,
      partialTranscript,
      recording: stage === "recording" || stage === "connecting",
      sessionActive: stage !== "idle",
      startDictation,
      startSession,
      stateLabel: stageLabel(stage),
      stopDictation,
    }),
    [
      endSession,
      error,
      lastTranscript,
      partialTranscript,
      stage,
      startDictation,
      startSession,
      stopDictation,
    ],
  );

  return (
    <DictationSessionContext.Provider value={value}>
      {children}
    </DictationSessionContext.Provider>
  );
}

export function useDictationSession() {
  const value = useContext(DictationSessionContext);
  if (!value)
    throw new Error(
      "useDictationSession must be used inside DictationSessionProvider",
    );
  return value;
}

function readNumber(key: string) {
  return Number(storage.get(key) ?? 0);
}

function readBoolean(key: string) {
  return readNumber(key) > 0;
}

function readBuildCredential() {
  const value = Constants.expoConfig?.extra?.timberVoxApiKey;
  return typeof value === "string" ? value.trim() : "";
}

function stageLabel(stage: SessionStage) {
  switch (stage) {
    case "idle":
      return "Session off";
    case "ready":
      return "Ready in background";
    case "connecting":
      return "Connecting to Voxtral…";
    case "recording":
      return "Listening…";
    case "processing":
      return "Finishing transcript…";
  }
}

function parseEvent(
  raw: string,
): { delta?: string; error?: string; final?: string; partial?: string } | null {
  try {
    const event = JSON.parse(raw) as Record<string, unknown>;
    if (event.error) {
      const providerError = event.error as Record<string, unknown>;
      return {
        error:
          typeof event.error === "string"
            ? event.error
            : typeof providerError.message === "string"
              ? providerError.message
              : JSON.stringify(event.error),
      };
    }
    const type = typeof event.type === "string" ? event.type : "";
    const text = typeof event.text === "string" ? event.text : "";
    if (type === "session.completed") {
      return {
        final: typeof event.transcript === "string" ? event.transcript : text,
      };
    }
    if (type === "transcript.delta") return { delta: text };
    if (type === "transcript.interim" || type === "transcript.committed") {
      return { partial: text };
    }
    return null;
  } catch {
    return null;
  }
}
