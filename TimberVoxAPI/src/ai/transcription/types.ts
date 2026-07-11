import { z } from "zod";

const TranscriptSpeakerSchema = z.union([z.string(), z.number()]);

const TimedTextSchema = z
  .object({
    endSeconds: z.number().nonnegative(),
    speaker: TranscriptSpeakerSchema.optional(),
    startSeconds: z.number().nonnegative(),
    text: z.string(),
  })
  .strict();

const TranscriptWordSchema = TimedTextSchema.extend({
  confidence: z.number().min(0).max(1).optional(),
}).strict();

const TranscriptSegmentSchema = TimedTextSchema.extend({
  confidence: z.number().min(0).max(1).optional(),
}).strict();

const TranscriptSpeakerTurnSchema = TimedTextSchema.strict();

export const BatchTranscriptionResultSchema = z
  .object({
    durationSeconds: z.number().nonnegative().optional(),
    language: z.string().optional(),
    providerMetadata: z.record(z.string(), z.unknown()).optional(),
    segments: z.array(TranscriptSegmentSchema).default([]),
    speakerTurns: z.array(TranscriptSpeakerTurnSchema).default([]),
    text: z.string(),
    warnings: z
      .array(
        z
          .object({
            code: z.string(),
            message: z.string(),
          })
          .strict()
      )
      .default([]),
    words: z.array(TranscriptWordSchema).default([]),
  })
  .strict();

type BatchTranscriptionResult = z.infer<typeof BatchTranscriptionResultSchema>;
export type TranscriptSpeakerTurn = z.infer<typeof TranscriptSpeakerTurnSchema>;
export type TranscriptSegment = z.infer<typeof TranscriptSegmentSchema>;
export type TranscriptWord = z.infer<typeof TranscriptWordSchema>;

export interface RemoteMediaSource {
  contentType: string;
  filename: string;
  sizeBytes: number;
  url: URL;
}

interface BatchTranscriptionProviderRequest {
  diarize?: boolean;
  language?: string;
  media: RemoteMediaSource;
  model: string;
  providerOptions?: Record<string, unknown>;
}

export interface BatchTranscriptionProvider {
  transcribe: (
    request: BatchTranscriptionProviderRequest
  ) => Promise<BatchTranscriptionResult>;
}
