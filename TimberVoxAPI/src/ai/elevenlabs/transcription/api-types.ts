import { z } from "zod";

const ElevenLabsWordSchema = z
  .object({
    end: z.number().nullable().optional(),
    logprob: z.number().optional(),
    speaker_id: z.string().nullable().optional(),
    start: z.number().nullable().optional(),
    text: z.string(),
    type: z.enum(["word", "spacing", "audio_event"]),
  })
  .catchall(z.unknown());

export const ElevenLabsTranscriptionResponseSchema = z
  .object({
    language_code: z.string().optional(),
    language_probability: z.number().optional(),
    text: z.string(),
    words: z.array(ElevenLabsWordSchema).optional(),
  })
  .catchall(z.unknown());
