import { readProviderResponse } from "../../transcription/http";
import { speakerTurnsFromWords } from "../../transcription/speaker-turns";
import type { BatchTranscriptionProvider } from "../../transcription/types";
import { ElevenLabsTranscriptionResponseSchema } from "./api-types";
import { ElevenLabsTranscriptionOptionsSchema } from "./options";

const ELEVENLABS_TRANSCRIPTION_URL =
  "https://api.elevenlabs.io/v1/speech-to-text";

export const createElevenLabsTranscriptionProvider = (config: {
  apiKey?: string;
  fetch?: typeof fetch;
}): BatchTranscriptionProvider => ({
  transcribe: async (request) => {
    if (!config.apiKey) {
      throw new Error("missing ELEVENLABS_API_KEY");
    }
    const parsedOptions = ElevenLabsTranscriptionOptionsSchema.parse(
      request.providerOptions ?? {}
    );
    const options = {
      ...parsedOptions,
      diarize: request.diarize ?? parsedOptions.diarize ?? false,
      languageCode: request.language ?? parsedOptions.languageCode,
      timestampsGranularity:
        parsedOptions.timestampsGranularity ?? ("word" as const),
    };
    const form = new FormData();
    form.set("model_id", request.model);
    form.set("source_url", request.media.url.toString());
    appendOption(form, "diarize", options.diarize);
    appendOption(form, "file_format", options.fileFormat);
    appendOption(form, "language_code", options.languageCode);
    appendOption(form, "num_speakers", options.numSpeakers);
    appendOption(form, "tag_audio_events", options.tagAudioEvents);
    appendOption(form, "timestamps_granularity", options.timestampsGranularity);

    const response = await (config.fetch ?? fetch)(
      ELEVENLABS_TRANSCRIPTION_URL,
      {
        body: form,
        headers: { "xi-api-key": config.apiKey },
        method: "POST",
      }
    );
    const { parsed: body, raw: providerResponse } = await readProviderResponse(
      "ElevenLabs",
      response,
      ElevenLabsTranscriptionResponseSchema
    );
    const words =
      body.words?.flatMap((word) =>
        word.type === "word" &&
        word.start !== null &&
        word.start !== undefined &&
        word.end !== null &&
        word.end !== undefined
          ? [
              {
                endSeconds: word.end,
                scores: {
                  confidence:
                    word.logprob === undefined
                      ? undefined
                      : Math.min(1, Math.exp(word.logprob)),
                  logProbability: word.logprob,
                },
                speaker: word.speaker_id ?? undefined,
                startSeconds: word.start,
                text: word.text,
              },
            ]
          : []
      ) ?? [];
    const tokens =
      body.words?.map((item) => ({
        endSeconds: item.end ?? undefined,
        kind: item.type,
        scores: { logProbability: item.logprob },
        speaker: item.speaker_id ?? undefined,
        startSeconds: item.start ?? undefined,
        text: item.text,
      })) ?? [];
    const audioEvents =
      body.words
        ?.filter((item) => item.type === "audio_event")
        .map((item) => ({
          endSeconds: item.end ?? undefined,
          startSeconds: item.start ?? undefined,
          text: item.text,
        })) ?? [];
    const speakerTurns = speakerTurnsFromWords(words);

    return {
      audioEvents,
      collections: {
        audioEvents: {
          availability:
            body.words === undefined ? "provider_omitted" : "available",
          source: "provider",
        },
        segments: {
          availability:
            body.words === undefined ? "provider_omitted" : "available",
          source: "derived",
        },
        speakerTurns: {
          availability:
            body.words === undefined ? "provider_omitted" : "available",
          source: "derived",
        },
        tokens: {
          availability:
            body.words === undefined ? "provider_omitted" : "available",
          source: "provider",
        },
        words: {
          availability:
            body.words === undefined ? "provider_omitted" : "available",
          source: "provider",
        },
      },
      durationSeconds: words.at(-1)?.endSeconds,
      language: body.language_code,
      languageConfidence: body.language_probability,
      providerMetadata: {
        languageProbability: body.language_probability,
      },
      providerResponse,
      segments: speakerTurns,
      speakerTurns,
      text: body.text,
      tokens,
      usage: {},
      warnings: [],
      words,
    };
  },
});

const appendOption = (
  form: FormData,
  key: string,
  value: boolean | number | string | undefined
): void => {
  if (value !== undefined) {
    form.set(key, String(value));
  }
};
