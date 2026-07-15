import { readProviderResponse } from "../../transcription/http";
import { speakerTurnsFromWords } from "../../transcription/speaker-turns";
import type { BatchTranscriptionProvider } from "../../transcription/types";
import { DeepgramTranscriptionResponseSchema } from "./api-types";
import {
  type DeepgramTranscriptionOptions,
  DeepgramTranscriptionOptionsSchema,
} from "./options";

const DEEPGRAM_TRANSCRIPTION_URL = "https://api.deepgram.com/v1/listen";

export const createDeepgramTranscriptionProvider = (config: {
  apiKey?: string;
  fetch?: typeof fetch;
}): BatchTranscriptionProvider => ({
  transcribe: async (request) => {
    if (!config.apiKey) {
      throw new Error("missing DEEPGRAM_API_KEY");
    }
    const providerOptions = DeepgramTranscriptionOptionsSchema.parse(
      request.providerOptions ?? {}
    );
    const options = {
      ...providerOptions,
      detectLanguage:
        request.language === undefined && providerOptions.language === undefined
          ? true
          : providerOptions.detectLanguage,
      diarize: request.diarize ?? providerOptions.diarize,
      language: request.language ?? providerOptions.language,
      utterances: providerOptions.utterances ?? true,
    };
    const url = new URL(DEEPGRAM_TRANSCRIPTION_URL);
    url.searchParams.set("model", request.model);
    appendDeepgramOptions(url, options);

    const response = await (config.fetch ?? fetch)(url, {
      body: JSON.stringify({ url: request.media.url.toString() }),
      headers: {
        authorization: `Token ${config.apiKey}`,
        "content-type": "application/json",
      },
      method: "POST",
    });
    const { parsed: body, raw: providerResponse } = await readProviderResponse(
      "Deepgram",
      response,
      DeepgramTranscriptionResponseSchema
    );
    const channel = body.results.channels.at(0);
    const alternative = channel?.alternatives.at(0);
    const words =
      alternative?.words?.map((word) => ({
        endSeconds: word.end,
        scores: {
          confidence: word.confidence,
          speakerConfidence: word.speaker_confidence,
        },
        speaker: word.speaker,
        startSeconds: word.start,
        text: word.punctuated_word ?? word.word,
      })) ?? [];
    const segments =
      body.results.utterances?.map((utterance) => ({
        endSeconds: utterance.end,
        scores: { confidence: utterance.confidence },
        speaker: utterance.speaker,
        startSeconds: utterance.start,
        text: utterance.transcript,
      })) ?? [];
    const speakerTurns =
      segments.filter((segment) => segment.speaker !== undefined).length > 0
        ? segments.map(({ endSeconds, speaker, startSeconds, text }) => ({
            endSeconds,
            speaker,
            startSeconds,
            text,
          }))
        : speakerTurnsFromWords(words);

    return {
      audioEvents: [],
      collections: deepgramCollections(
        alternative?.words,
        body.results.utterances
      ),
      durationSeconds: body.metadata?.duration,
      language: channel?.detected_language,
      providerMetadata: {
        requestId: body.metadata?.request_id,
        sha256: body.metadata?.sha256,
      },
      providerResponse,
      segments,
      speakerTurns,
      text: alternative?.transcript ?? "",
      tokens: [],
      usage: {},
      warnings: [],
      words,
    };
  },
});

const deepgramCollections = (
  words: unknown[] | undefined,
  utterances: unknown[] | undefined
) => ({
  audioEvents: { availability: "unsupported" as const },
  segments: {
    availability: providerAvailability(utterances),
    source: "provider" as const,
  },
  speakerTurns: {
    availability: providerAvailability(utterances ?? words),
    source: "derived" as const,
  },
  tokens: { availability: "unsupported" as const },
  words: {
    availability: providerAvailability(words),
    source: "provider" as const,
  },
});

const providerAvailability = (value: unknown[] | undefined) =>
  value === undefined ? ("provider_omitted" as const) : ("available" as const);

const appendDeepgramOptions = (
  url: URL,
  options: DeepgramTranscriptionOptions
): void => {
  append(url, "detect_entities", options.detectEntities);
  append(url, "detect_language", options.detectLanguage);
  append(url, "diarize", options.diarize);
  append(url, "filler_words", options.fillerWords);
  append(url, "intents", options.intents);
  append(url, "keyterm", options.keyterm);
  append(url, "language", options.language);
  append(url, "paragraphs", options.paragraphs);
  append(url, "punctuate", options.punctuate);
  append(url, "redact", options.redact);
  append(url, "replace", options.replace);
  append(url, "search", options.search);
  append(url, "sentiment", options.sentiment);
  append(url, "smart_format", options.smartFormat);
  append(url, "summarize", options.summarize);
  append(url, "topics", options.topics);
  append(url, "utterances", options.utterances);
  append(url, "utt_split", options.uttSplit);
};

const append = (
  url: URL,
  key: string,
  value: boolean | number | string | readonly string[] | undefined
): void => {
  for (const item of Array.isArray(value) ? value : [value]) {
    if (item !== undefined) {
      url.searchParams.append(key, String(item));
    }
  }
};
