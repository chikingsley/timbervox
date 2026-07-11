import { z } from "zod";

const DeepgramWordSchema = z
  .object({
    confidence: z.number().optional(),
    end: z.number(),
    punctuated_word: z.string().optional(),
    speaker: z.number().optional(),
    speaker_confidence: z.number().optional(),
    start: z.number(),
    word: z.string(),
  })
  .catchall(z.unknown());

const DeepgramAlternativeSchema = z
  .object({
    transcript: z.string(),
    words: z.array(DeepgramWordSchema).optional(),
  })
  .catchall(z.unknown());

const DeepgramUtteranceSchema = z
  .object({
    confidence: z.number().optional(),
    end: z.number(),
    speaker: z.number().optional(),
    start: z.number(),
    transcript: z.string(),
    words: z.array(DeepgramWordSchema).optional(),
  })
  .catchall(z.unknown());

export const DeepgramTranscriptionResponseSchema = z
  .object({
    metadata: z
      .object({
        duration: z.number().optional(),
        request_id: z.string().optional(),
        sha256: z.string().optional(),
      })
      .catchall(z.unknown())
      .optional(),
    results: z
      .object({
        channels: z.array(
          z
            .object({
              alternatives: z.array(DeepgramAlternativeSchema),
              detected_language: z.string().optional(),
            })
            .catchall(z.unknown())
        ),
        utterances: z.array(DeepgramUtteranceSchema).optional(),
      })
      .catchall(z.unknown()),
  })
  .catchall(z.unknown());
