import type { RealtimeAsrProviderId } from "../models/types";
import type {
  TranscriptSegment,
  TranscriptSpeakerTurn,
  TranscriptWord,
} from "../transcription/types";
import type { RealtimeTranscriptEvent } from "./normalize";

export const REALTIME_PROTOCOL_VERSION = 1 as const;

interface RealtimeEventBase {
  protocol_version: typeof REALTIME_PROTOCOL_VERSION;
  sequence: number;
  session_id: string;
}

export interface RealtimeSessionStartedEvent extends RealtimeEventBase {
  language: string | null;
  model: string;
  type: "session.started";
}

export interface RealtimeTranscriptProtocolEvent extends RealtimeEventBase {
  segments: TranscriptSegment[];
  speaker_turns: TranscriptSpeakerTurn[];
  speech_final?: boolean;
  text: string;
  type: "transcript.committed" | "transcript.delta" | "transcript.interim";
  words: TranscriptWord[];
}

export interface RealtimeSessionCompletedEvent extends RealtimeEventBase {
  audio_bytes: number;
  audio_seconds: number | null;
  ended_at: string;
  language: string | null;
  message_count: number;
  model: string;
  provider: RealtimeAsrProviderId;
  started_at: string;
  status: "succeeded";
  transcript: string;
  type: "session.completed";
}

export interface RealtimeSessionFailedEvent extends RealtimeEventBase {
  audio_bytes: number;
  ended_at: string;
  error: {
    code: "provider_error" | "session_error";
    message: string;
    retryable: boolean;
  };
  language: string | null;
  message_count: number;
  model: string;
  provider: RealtimeAsrProviderId;
  started_at: string;
  status: "failed";
  transcript: string;
  type: "session.failed";
}

export type RealtimeSessionTerminalEvent =
  | RealtimeSessionCompletedEvent
  | RealtimeSessionFailedEvent;

export interface RealtimeProtocolSession {
  audioBytes: number;
  audioSeconds?: number | null;
  endedAt: string;
  error?: string | null;
  errorCode?: "provider_error" | "session_error";
  language: string | null;
  messageCount: number;
  model: string;
  provider: RealtimeAsrProviderId;
  sampleRate: number | null;
  sessionId: string;
  startedAt: string;
  status: "failed" | "succeeded";
  transcript: string;
}

const audioSeconds = (
  audioBytes: number,
  sampleRate: number | null
): number | null => {
  if (audioBytes <= 0 || !sampleRate) {
    return null;
  }
  return audioBytes / 2 / sampleRate;
};

export const sessionStartedEvent = (input: {
  language: string | null;
  model: string;
  sequence: number;
  sessionId: string;
}): RealtimeSessionStartedEvent => ({
  language: input.language,
  model: input.model,
  protocol_version: REALTIME_PROTOCOL_VERSION,
  sequence: input.sequence,
  session_id: input.sessionId,
  type: "session.started",
});

export const transcriptProtocolEvent = (
  sessionId: string,
  sequence: number,
  event: RealtimeTranscriptEvent
): RealtimeTranscriptProtocolEvent | null => {
  if (event.delivery === "complete") {
    return null;
  }
  let type: RealtimeTranscriptProtocolEvent["type"] = "transcript.interim";
  if (event.delivery === "committed") {
    type = "transcript.committed";
  } else if (event.delivery === "delta") {
    type = "transcript.delta";
  }
  return {
    protocol_version: REALTIME_PROTOCOL_VERSION,
    segments: event.segments,
    sequence,
    session_id: sessionId,
    speaker_turns: event.speakerTurns,
    ...(event.speechFinal === undefined
      ? {}
      : { speech_final: event.speechFinal }),
    text: event.text,
    type,
    words: event.words,
  };
};

export const terminalSessionEvent = (
  session: RealtimeProtocolSession,
  sequence: number
): RealtimeSessionTerminalEvent => {
  const base = {
    audio_bytes: session.audioBytes,
    ended_at: session.endedAt,
    language: session.language,
    message_count: session.messageCount,
    model: session.model,
    protocol_version: REALTIME_PROTOCOL_VERSION,
    provider: session.provider,
    sequence,
    session_id: session.sessionId,
    started_at: session.startedAt,
    transcript: session.transcript,
  } as const;
  if (session.status === "failed") {
    return {
      ...base,
      error: {
        code: session.errorCode ?? "provider_error",
        message: session.error ?? "realtime transcription failed",
        retryable: true,
      },
      status: "failed",
      type: "session.failed",
    };
  }
  return {
    ...base,
    audio_seconds:
      session.audioSeconds ??
      audioSeconds(session.audioBytes, session.sampleRate),
    status: "succeeded",
    type: "session.completed",
  };
};
