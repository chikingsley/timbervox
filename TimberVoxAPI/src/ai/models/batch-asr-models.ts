import {
  deepgramNova2Languages,
  deepgramNova3Languages,
  elevenLabsScribeV2Languages,
  mistralVoxtralLanguages,
} from "./asr-languages";
import { mapBatchAsrModels } from "./map";
import type { BatchAsrModelEntry } from "./types";

const DEEPGRAM_BATCH_ASR_MODEL_IDS = ["nova-3", "nova-2"] as const;

const ELEVENLABS_BATCH_ASR_MODEL_IDS = ["scribe_v2"] as const;

const MISTRAL_BATCH_ASR_MODEL_IDS = ["voxtral-mini-latest"] as const;

export const BATCH_ASR_MODEL_MAP = {
  ...mapBatchAsrModels("deepgram", DEEPGRAM_BATCH_ASR_MODEL_IDS, {
    "nova-2": deepgramNova2Languages,
    "nova-3": deepgramNova3Languages,
  }),
  ...mapBatchAsrModels("elevenlabs", ELEVENLABS_BATCH_ASR_MODEL_IDS, {
    scribe_v2: elevenLabsScribeV2Languages,
  }),
  ...mapBatchAsrModels("mistral", MISTRAL_BATCH_ASR_MODEL_IDS, {
    "voxtral-mini-latest": mistralVoxtralLanguages,
  }),
} as const satisfies Record<string, BatchAsrModelEntry>;

export const resolveBatchAsrModel = (modelId: string): BatchAsrModelEntry => {
  const model =
    BATCH_ASR_MODEL_MAP[modelId as keyof typeof BATCH_ASR_MODEL_MAP];
  if (!model) {
    throw new Error(`unsupported transcription model: ${modelId}`);
  }
  return model;
};
