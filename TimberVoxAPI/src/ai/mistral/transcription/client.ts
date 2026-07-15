import { readProviderResponse } from "../../transcription/http";
import type { BatchTranscriptionProvider } from "../../transcription/types";
import { mistralHeaders, mistralUrl } from "../config";
import { MistralTranscriptionResponseSchema } from "./api-types";
import {
  appendMistralTranscriptionOptions,
  MistralTranscriptionModelOptionsSchema,
} from "./model-options";

const TRANSCRIPTIONS_PATH = "/v1/audio/transcriptions";

export const createMistralTranscriptionProvider = (config: {
  apiKey?: string;
  baseUrl?: string;
  fetch?: typeof fetch;
}): BatchTranscriptionProvider => ({
  transcribe: async (request) => {
    if (!config.apiKey) {
      throw new Error("missing MISTRAL_API_KEY");
    }
    const parsedOptions = MistralTranscriptionModelOptionsSchema.parse(
      request.providerOptions ?? {}
    );
    const diarize = request.diarize ?? parsedOptions.diarize ?? false;
    const timestampGranularity =
      parsedOptions.timestampGranularities?.[0] ??
      (diarize ? "segment" : "word");
    if (diarize && timestampGranularity !== "segment") {
      throw new Error(
        "Mistral batch diarization requires segment timestamp granularity"
      );
    }
    const options = {
      ...parsedOptions,
      diarize,
      language: request.language ?? parsedOptions.language,
      timestampGranularities: [timestampGranularity],
    };
    const form = new FormData();
    form.set("model", request.model);
    form.set("file_url", request.media.url.toString());
    appendMistralTranscriptionOptions(form, options);

    const response = await (config.fetch ?? fetch)(
      mistralUrl({ baseUrl: config.baseUrl }, TRANSCRIPTIONS_PATH),
      {
        body: form,
        headers: mistralHeaders({ apiKey: config.apiKey }),
        method: "POST",
      }
    );
    const { parsed: body, raw: providerResponse } = await readProviderResponse(
      "Mistral",
      response,
      MistralTranscriptionResponseSchema
    );
    const timedItems =
      body.segments?.map((item) => ({
        endSeconds: item.end,
        scores: { score: item.score ?? undefined },
        speaker: item.speaker_id ?? undefined,
        startSeconds: item.start,
        text: item.text,
      })) ?? [];
    const segments = timestampGranularity === "segment" ? timedItems : [];
    const words = timestampGranularity === "word" ? timedItems : [];

    return {
      audioEvents: [],
      collections: mistralCollections({
        diarize,
        hasTimedItems: body.segments !== undefined,
        timestampGranularity,
      }),
      durationSeconds: body.usage.prompt_audio_seconds ?? undefined,
      language: body.language ?? undefined,
      providerMetadata: {
        completionTokens: body.usage.completion_tokens,
        promptAudioSeconds: body.usage.prompt_audio_seconds,
        promptTokens: body.usage.prompt_tokens,
        totalTokens: body.usage.total_tokens,
      },
      providerResponse,
      segments,
      speakerTurns: segments
        .filter((segment) => segment.speaker !== undefined)
        .map(({ endSeconds, speaker, startSeconds, text }) => ({
          endSeconds,
          speaker,
          startSeconds,
          text,
        })),
      text: body.text,
      tokens: [],
      usage: {
        inputTokens: body.usage.prompt_tokens,
        outputTokens: body.usage.completion_tokens,
        totalTokens: body.usage.total_tokens,
      },
      warnings: [],
      words,
    };
  },
});

const mistralCollections = (input: {
  diarize: boolean;
  hasTimedItems: boolean;
  timestampGranularity: "segment" | "word";
}) => ({
  audioEvents: { availability: "unsupported" as const },
  segments: requestedCollection(
    input.timestampGranularity === "segment",
    input.hasTimedItems,
    "provider"
  ),
  speakerTurns: requestedCollection(
    input.diarize && input.timestampGranularity === "segment",
    input.hasTimedItems,
    "derived"
  ),
  tokens: { availability: "unsupported" as const },
  words: requestedCollection(
    input.timestampGranularity === "word",
    input.hasTimedItems,
    "provider"
  ),
});

const requestedCollection = (
  requested: boolean,
  returned: boolean,
  source: "derived" | "provider"
) => {
  if (!requested) {
    return { availability: "not_requested" as const };
  }
  return {
    availability: returned
      ? ("available" as const)
      : ("provider_omitted" as const),
    source,
  };
};
