import { z } from "zod";

const DeepgramRealtimeEventSchema = z
  .object({
    type: z.enum([
      "Results",
      "Metadata",
      "UtteranceEnd",
      "SpeechStarted",
      "Error",
    ]),
  })
  .catchall(z.unknown());

export type DeepgramRealtimeEvent = z.infer<typeof DeepgramRealtimeEventSchema>;

const parseJSON = (data: string): unknown => {
  try {
    return JSON.parse(data);
  } catch {
    return null;
  }
};

export const parseDeepgramRealtimeEvent = (
  data: string
): DeepgramRealtimeEvent | undefined => {
  const parsed = DeepgramRealtimeEventSchema.safeParse(parseJSON(data));
  if (parsed.success) {
    return parsed.data;
  }
};
