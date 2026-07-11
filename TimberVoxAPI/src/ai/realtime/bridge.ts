import type { Env } from "../../bindings";
import {
  connectDeepgramRealtime,
  type DeepgramRealtimeOptions,
  sendDeepgramAudio,
  sendDeepgramCloseStream,
  sendDeepgramFinalize,
  sendDeepgramKeepAlive,
} from "../deepgram/realtime/client";
import { parseDeepgramRealtimeEvent } from "../deepgram/realtime/events";
import {
  connectMistralRealtime,
  normalizeMistralRealtimeAudioEncoding,
  sendMistralInputAudioAppend,
  sendMistralInputAudioEnd,
  sendMistralInputAudioFlush,
} from "../mistral/realtime/client";
import { parseMistralRealtimeEvent } from "../mistral/realtime/events";
import type { RealtimeAsrProviderId } from "../models/types";
import {
  normalizeDeepgramTranscriptEvent,
  normalizeMistralTranscriptEvent,
  type RealtimeTranscriptEvent,
} from "./normalize";

export interface RealtimeProviderConfig {
  deepgram: DeepgramRealtimeOptions;
  encoding: string | null;
  provider: RealtimeAsrProviderId;
  sampleRate: number | null;
  targetStreamingDelayMs: number | null;
  upstreamModel: string;
}

interface ParsedRealtimeProviderMessage {
  providerError?: string;
  providerEvent?: unknown;
  shouldPersistProviderEvent: boolean;
  transcriptEvent?: RealtimeTranscriptEvent;
}

export interface RealtimeProviderBridge {
  close: (socket: WebSocket) => void;
  closeStream: (socket: WebSocket) => void;
  connect: () => Promise<WebSocket>;
  forwardClientMessage: (socket: WebSocket, message: unknown) => boolean;
  parseMessage: (data: string) => ParsedRealtimeProviderMessage;
  provider: RealtimeAsrProviderId;
  sendAudio: (socket: WebSocket, audio: Uint8Array) => void;
}

export const createRealtimeProviderBridge = (
  env: Env,
  config: RealtimeProviderConfig
): RealtimeProviderBridge =>
  config.provider === "deepgram"
    ? deepgramBridge(env, config)
    : mistralBridge(env, config);

const deepgramBridge = (
  env: Env,
  config: RealtimeProviderConfig
): RealtimeProviderBridge => ({
  close: sendDeepgramCloseStream,
  closeStream: (socket) => {
    sendDeepgramFinalize(socket);
    sendDeepgramCloseStream(socket);
  },
  connect: () =>
    connectDeepgramRealtime({
      apiKey: env.DEEPGRAM_API_KEY,
      model: config.upstreamModel,
      options: config.deepgram,
    }),
  forwardClientMessage: (socket, message) => {
    const type = deepgramControlType(message);
    if (!type) {
      return false;
    }
    if (type === "close") {
      sendDeepgramCloseStream(socket);
    } else if (type === "finalize") {
      sendDeepgramFinalize(socket);
    } else {
      sendDeepgramKeepAlive(socket);
    }
    return true;
  },
  parseMessage: (data) => {
    const providerEvent = parseDeepgramRealtimeEvent(data);
    const transcriptEvent = providerEvent
      ? (normalizeDeepgramTranscriptEvent(providerEvent) ?? undefined)
      : undefined;
    return {
      providerError:
        providerEvent?.type === "Error"
          ? describeProviderError(providerEvent)
          : undefined,
      providerEvent,
      shouldPersistProviderEvent: providerEvent?.type === "Results",
      transcriptEvent,
    };
  },
  provider: "deepgram",
  sendAudio: sendDeepgramAudio,
});

const mistralBridge = (
  env: Env,
  config: RealtimeProviderConfig
): RealtimeProviderBridge => ({
  close: sendMistralInputAudioEnd,
  closeStream: (socket) => {
    sendMistralInputAudioFlush(socket);
    sendMistralInputAudioEnd(socket);
  },
  connect: () =>
    connectMistralRealtime({
      apiKey: env.MISTRAL_API_KEY,
      model: config.upstreamModel,
      session: {
        audioFormat: {
          encoding: normalizeMistralRealtimeAudioEncoding(
            config.encoding ?? "pcm_s16le"
          ),
          sampleRate: config.sampleRate ?? 16_000,
        },
        targetStreamingDelayMs: config.targetStreamingDelayMs ?? undefined,
      },
    }),
  forwardClientMessage: (socket, message) => {
    if (!isMistralClientMessage(message)) {
      return false;
    }
    socket.send(JSON.stringify(message));
    return true;
  },
  parseMessage: (data) => {
    const providerEvent = parseMistralRealtimeEvent(data);
    const transcriptEvent = providerEvent
      ? (normalizeMistralTranscriptEvent(providerEvent) ?? undefined)
      : undefined;
    return {
      providerError:
        providerEvent?.type === "error"
          ? describeProviderError(providerEvent.error)
          : undefined,
      providerEvent,
      shouldPersistProviderEvent: providerEvent?.type === "transcription.done",
      transcriptEvent,
    };
  },
  provider: "mistral",
  sendAudio: sendMistralInputAudioAppend,
});

type DeepgramControlType = "close" | "finalize" | "keepAlive";

const deepgramControlType = (message: unknown): DeepgramControlType | null => {
  if (typeof message !== "object" || message === null || !("type" in message)) {
    return null;
  }
  if (message.type === "CloseStream" || message.type === "close_stream") {
    return "close";
  }
  if (message.type === "Finalize" || message.type === "finalize") {
    return "finalize";
  }
  if (message.type === "KeepAlive" || message.type === "keep_alive") {
    return "keepAlive";
  }
  return null;
};

const isMistralClientMessage = (value: unknown): value is { type: string } => {
  if (typeof value !== "object" || value === null || !("type" in value)) {
    return false;
  }
  const { type } = value;
  return (
    type === "input_audio.append" ||
    type === "input_audio.flush" ||
    type === "input_audio.end" ||
    type === "session.update"
  );
};

const describeProviderError = (value: unknown): string => {
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "object" && value !== null) {
    const record = value as Record<string, unknown>;
    if (typeof record.message === "string") {
      return record.message;
    }
    if (record.message !== undefined) {
      return JSON.stringify(record.message);
    }
  }
  return JSON.stringify(value);
};
