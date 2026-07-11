import {
  deepgramNova2Languages,
  deepgramNova3Languages,
  mistralVoxtralLanguages,
} from "./asr-languages";
import { mapRealtimeAsrModels } from "./map";
import type { RealtimeAsrModelEntry } from "./types";

const DEEPGRAM_REALTIME_ASR_MODEL_IDS = ["nova-3", "nova-2"] as const;

const MISTRAL_REALTIME_ASR_MODEL_IDS = [
  "voxtral-mini-transcribe-realtime-2602",
] as const;

export const REALTIME_ASR_MODEL_MAP = {
  ...mapRealtimeAsrModels("deepgram", DEEPGRAM_REALTIME_ASR_MODEL_IDS, {
    "nova-2": deepgramNova2Languages,
    "nova-3": deepgramNova3Languages,
  }),
  ...mapRealtimeAsrModels("mistral", MISTRAL_REALTIME_ASR_MODEL_IDS, {
    "voxtral-mini-transcribe-realtime-2602": mistralVoxtralLanguages,
  }),
} as const satisfies Record<string, RealtimeAsrModelEntry>;

export const resolveRealtimeAsrModel = (
  modelId: string
): RealtimeAsrModelEntry => {
  const model =
    REALTIME_ASR_MODEL_MAP[modelId as keyof typeof REALTIME_ASR_MODEL_MAP];
  if (!model) {
    throw new Error(`unsupported realtime model: ${modelId}`);
  }
  return model;
};

export const resolveRealtimeLanguage = (
  route: RealtimeAsrModelEntry,
  requestedLanguage: string | undefined
): string | undefined =>
  requestedLanguage ?? (route.provider === "deepgram" ? "multi" : undefined);
