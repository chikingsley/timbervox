import type { RealtimeAsrProviderId } from "./types";

const deepgramRealtimeAsrOptionNames = [
  "channels",
  "detect_entities",
  "diarize",
  "diarize_model",
  "dictation",
  "encoding",
  "endpointing",
  "filler_words",
  "interim_results",
  "keyterm",
  "keywords",
  "language",
  "mip_opt_out",
  "multichannel",
  "numerals",
  "profanity_filter",
  "punctuate",
  "redact",
  "replace",
  "sample_rate",
  "search",
  "smart_format",
  "tag",
  "utterance_end_ms",
  "vad_events",
  "version",
] as const;

const mistralRealtimeAsrOptionNames = [
  "audio_format.encoding",
  "audio_format.sample_rate",
  "target_streaming_delay_ms",
] as const;

export const REALTIME_ASR_OPTION_NAMES_BY_PROVIDER = {
  deepgram: deepgramRealtimeAsrOptionNames,
  mistral: mistralRealtimeAsrOptionNames,
} as const satisfies Record<RealtimeAsrProviderId, readonly string[]>;
