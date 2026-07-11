import type { DeepgramRealtimeEvent } from "../deepgram/realtime/events";
import type { MistralRealtimeEvent } from "../mistral/realtime/events";
import type { RealtimeAsrProviderId } from "../models/types";
import { speakerTurnsFromWords } from "../transcription/speaker-turns";
import type {
  TranscriptSegment,
  TranscriptSpeakerTurn,
  TranscriptWord,
} from "../transcription/types";

export interface RealtimeTranscriptEvent {
  delivery: "complete" | "committed" | "delta" | "interim";
  isFinal: boolean;
  providerEvent: unknown;
  segments: TranscriptSegment[];
  speakerTurns: TranscriptSpeakerTurn[];
  speechFinal?: boolean;
  text: string;
  type: "transcript";
  words: TranscriptWord[];
}

const wordText = (value: Record<string, unknown>): string | null => {
  const candidate = value.punctuated_word ?? value.text ?? value.word;
  return typeof candidate === "string" && candidate.trim()
    ? candidate.trim()
    : null;
};

const normalizeSpeaker = (value: unknown): string | number | undefined => {
  if (value === null || value === undefined || value === "") {
    return;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    return value;
  }
};

const normalizeWords = (value: unknown): TranscriptWord[] => {
  if (!Array.isArray(value)) {
    return [];
  }
  const words: TranscriptWord[] = [];
  for (const item of value) {
    if (typeof item !== "object" || item === null) {
      continue;
    }
    const raw = item as Record<string, unknown>;
    const text = wordText(raw);
    if (!text || typeof raw.start !== "number" || typeof raw.end !== "number") {
      continue;
    }
    const word: TranscriptWord = {
      endSeconds: raw.end,
      startSeconds: raw.start,
      text,
    };
    if (typeof raw.confidence === "number") {
      word.confidence = raw.confidence;
    }
    const speaker = normalizeSpeaker(raw.speaker ?? raw.speaker_id);
    if (speaker !== undefined) {
      word.speaker = speaker;
    }
    words.push(word);
  }
  return words;
};

export const normalizeDeepgramTranscriptEvent = (
  event: DeepgramRealtimeEvent
): RealtimeTranscriptEvent | null => {
  if (event.type !== "Results") {
    return null;
  }
  const raw = event as Record<string, unknown>;
  const channel = raw.channel as
    | { alternatives?: { transcript?: string; words?: unknown }[] }
    | undefined;
  const [alternative] = channel?.alternatives ?? [];
  const text = alternative?.transcript?.trim();
  if (!text) {
    return null;
  }
  const words = normalizeWords(alternative?.words);
  const startSeconds = typeof raw.start === "number" ? raw.start : undefined;
  const duration = typeof raw.duration === "number" ? raw.duration : undefined;
  const segments: TranscriptSegment[] =
    startSeconds === undefined || duration === undefined
      ? []
      : [
          {
            endSeconds: startSeconds + duration,
            startSeconds,
            text,
          },
        ];
  return {
    delivery: raw.is_final ? "committed" : "interim",
    isFinal: Boolean(raw.is_final),
    providerEvent: event,
    segments,
    speakerTurns: speakerTurnsFromWords(words),
    ...(typeof raw.speech_final === "boolean"
      ? { speechFinal: raw.speech_final }
      : {}),
    text,
    type: "transcript",
    words,
  };
};

export const normalizeMistralTranscriptEvent = (
  event: MistralRealtimeEvent
): RealtimeTranscriptEvent | null => {
  if (event.type === "transcription.segment") {
    const segment: TranscriptSegment = {
      endSeconds: event.end,
      speaker: normalizeSpeaker(event.speaker_id),
      startSeconds: event.start,
      text: event.text,
    };
    const speakerTurns: TranscriptSpeakerTurn[] =
      segment.speaker === undefined
        ? []
        : [
            {
              endSeconds: segment.endSeconds,
              speaker: segment.speaker,
              startSeconds: segment.startSeconds,
              text: segment.text,
            },
          ];
    return {
      delivery: "committed",
      isFinal: true,
      providerEvent: event,
      segments: [segment],
      speakerTurns,
      text: event.text,
      type: "transcript",
      words: [],
    };
  }
  if (event.type === "transcription.done") {
    return transcriptEvent(event, event.text, true, "complete");
  }
  if (event.type === "transcription.text.delta") {
    return transcriptEvent(event, event.text, false, "delta");
  }
  return null;
};

const transcriptEvent = (
  providerEvent: unknown,
  text: string,
  isFinal: boolean,
  delivery: RealtimeTranscriptEvent["delivery"]
): RealtimeTranscriptEvent => ({
  delivery,
  isFinal,
  providerEvent,
  segments: [],
  speakerTurns: [],
  text,
  type: "transcript",
  words: [],
});

export const finalRealtimeTranscript = (
  provider: RealtimeAsrProviderId,
  events: readonly RealtimeTranscriptEvent[]
): string => {
  const finalEvents = events.filter((event) => event.isFinal && event.text);
  if (provider === "deepgram") {
    return finalEvents
      .map((event) => event.text)
      .join(" ")
      .trim();
  }
  return (
    finalEvents.at(-1)?.text ??
    events
      .filter((event) => event.text)
      .map((event) => event.text)
      .join("")
  ).trim();
};
