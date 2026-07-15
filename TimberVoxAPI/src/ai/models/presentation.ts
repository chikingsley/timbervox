import type {
  ModelAccuracyPresentation,
  ModelSpeedPresentation,
} from "./types";

const providerWer = (
  value: number,
  benchmark: string
): ModelAccuracyPresentation => ({
  benchmark,
  metric: "wer",
  source: "provider-published",
  value,
});

const effectiveTps = (value: number): ModelSpeedPresentation => ({
  approximate: true,
  kind: "effective-tps",
  measuredAt: "2026-07-14",
  profile: "timbervox-text-stream-v2",
  source: "timbervox-benchmark",
  value,
});

const TRANSCRIPTION_ACCURACY: Readonly<
  Record<string, ModelAccuracyPresentation>
> = {
  "deepgram-nova-2": providerWer(10.7, "Deepgram mixed-domain audio"),
  "deepgram-nova-3": providerWer(6.84, "Deepgram mixed-domain audio"),
  "mistral-voxtral-mini-latest": providerWer(5.9, "English FLEURS at 240 ms"),
};

const LANGUAGE_MODEL_SPEED: Readonly<Record<string, ModelSpeedPresentation>> = {
  "cerebras-gemma-4-31b": effectiveTps(320.9),
  "cerebras-gpt-oss-120b": effectiveTps(130.6),
  "google-gemini-3.1-flash-lite": effectiveTps(272.3),
  "groq-openai/gpt-oss-120b": effectiveTps(14.5),
  "groq-qwen/qwen3.6-27b": effectiveTps(331.7),
  "mistral-mistral-large-latest": effectiveTps(67.3),
  "mistral-mistral-small-latest": effectiveTps(141.8),
};

export const transcriptionAccuracy = (
  modelId: string
): ModelAccuracyPresentation | undefined => TRANSCRIPTION_ACCURACY[modelId];

export const languageModelSpeed = (
  modelId: string
): ModelSpeedPresentation | undefined => LANGUAGE_MODEL_SPEED[modelId];

export const realtimeSpeed = (): ModelSpeedPresentation => ({
  approximate: false,
  kind: "realtime",
  source: "route-capability",
});
