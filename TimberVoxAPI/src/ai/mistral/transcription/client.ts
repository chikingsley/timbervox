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
    const body = await readProviderResponse(
      "Mistral",
      response,
      MistralTranscriptionResponseSchema
    );
    const timedItems =
      body.segments?.map((item) => ({
        confidence: item.score ?? undefined,
        endSeconds: item.end,
        speaker: item.speaker_id ?? undefined,
        startSeconds: item.start,
        text: item.text,
      })) ?? [];
    const segments = timestampGranularity === "segment" ? timedItems : [];
    const words = timestampGranularity === "word" ? timedItems : [];

    return {
      durationSeconds: body.usage.prompt_audio_seconds ?? undefined,
      language: body.language ?? undefined,
      providerMetadata: {
        completionTokens: body.usage.completion_tokens,
        promptAudioSeconds: body.usage.prompt_audio_seconds,
        promptTokens: body.usage.prompt_tokens,
        totalTokens: body.usage.total_tokens,
      },
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
      warnings: [],
      words,
    };
  },
});
