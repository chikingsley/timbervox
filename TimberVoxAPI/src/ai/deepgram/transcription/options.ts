import { z } from "zod";

const StringOrStringsSchema = z.union([
  z.string().min(1),
  z.array(z.string().min(1)).min(1),
]);

export const DeepgramTranscriptionOptionsSchema = z
  .object({
    detectEntities: z.boolean().optional(),
    detectLanguage: z.boolean().optional(),
    diarize: z.boolean().optional(),
    fillerWords: z.boolean().optional(),
    intents: z.boolean().optional(),
    keyterm: StringOrStringsSchema.optional(),
    language: z.string().min(1).optional(),
    paragraphs: z.boolean().optional(),
    punctuate: z.boolean().optional(),
    redact: StringOrStringsSchema.optional(),
    replace: StringOrStringsSchema.optional(),
    search: StringOrStringsSchema.optional(),
    sentiment: z.boolean().optional(),
    smartFormat: z.boolean().optional(),
    summarize: z.union([z.literal("v2"), z.literal(false)]).optional(),
    topics: z.boolean().optional(),
    utterances: z.boolean().optional(),
    uttSplit: z.number().positive().optional(),
  })
  .strict();

export type DeepgramTranscriptionOptions = z.infer<
  typeof DeepgramTranscriptionOptionsSchema
>;
