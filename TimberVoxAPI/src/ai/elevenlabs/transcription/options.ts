import { z } from "zod";

export const ElevenLabsTranscriptionOptionsSchema = z
  .object({
    diarize: z.boolean().optional(),
    fileFormat: z.enum(["pcm_s16le_16", "other"]).optional(),
    languageCode: z.string().min(1).optional(),
    numSpeakers: z.number().int().min(1).max(32).optional(),
    tagAudioEvents: z.boolean().optional(),
    timestampsGranularity: z.enum(["none", "word", "character"]).optional(),
  })
  .strict();
