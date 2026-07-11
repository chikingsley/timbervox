import type { BatchAsrProviderId } from "./types";

const deepgramBatchAsrOptionNames = [
  "language",
  "detectLanguage",
  "smartFormat",
  "punctuate",
  "paragraphs",
  "summarize",
  "topics",
  "intents",
  "sentiment",
  "detectEntities",
  "redact",
  "replace",
  "search",
  "keyterm",
  "diarize",
  "utterances",
  "uttSplit",
  "fillerWords",
] as const;

const elevenLabsBatchAsrOptionNames = [
  "languageCode",
  "tagAudioEvents",
  "numSpeakers",
  "timestampsGranularity",
  "diarize",
  "fileFormat",
] as const;

const mistralBatchAsrOptionNames = [
  "contextBias",
  "diarize",
  "language",
  "temperature",
  "timestampGranularities",
] as const;

export const BATCH_ASR_OPTION_NAMES_BY_PROVIDER = {
  deepgram: deepgramBatchAsrOptionNames,
  elevenlabs: elevenLabsBatchAsrOptionNames,
  mistral: mistralBatchAsrOptionNames,
} as const satisfies Record<BatchAsrProviderId, readonly string[]>;
