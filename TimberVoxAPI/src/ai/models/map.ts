import type {
  BatchAsrModelEntry,
  BatchAsrProviderId,
  LanguageModelEntry,
  LanguageModelProviderId,
  RealtimeAsrModelEntry,
  RealtimeAsrProviderId,
} from "./types";

const BATCH_AUTOMATIC_LANGUAGE_SUPPORT: Record<BatchAsrProviderId, boolean> = {
  deepgram: true,
  elevenlabs: true,
  mistral: true,
};

const REALTIME_AUTOMATIC_LANGUAGE_SUPPORT: Record<
  RealtimeAsrProviderId,
  boolean
> = {
  deepgram: true,
  mistral: true,
};

export const mapLanguageModels = <TProvider extends LanguageModelProviderId>(
  provider: TProvider,
  models: readonly string[]
): Record<string, LanguageModelEntry> =>
  Object.fromEntries(
    models.map((model) => [
      `${provider}-${model}`,
      {
        provider,
        providerModelId: `${provider}:${model}`,
        upstreamModel: model,
      },
    ])
  );

export const mapBatchAsrModels = <
  TProvider extends BatchAsrProviderId,
  const TModels extends readonly string[],
>(
  provider: TProvider,
  models: TModels,
  supportedLanguagesByModel: Record<TModels[number], readonly string[]>
): Record<string, BatchAsrModelEntry> =>
  Object.fromEntries(
    models.map((model) => [
      `${provider}-${model}`,
      {
        provider,
        providerModelId: `${provider}:${model}`,
        supportedLanguages: supportedLanguagesByModel[model as TModels[number]],
        supportsAutomaticLanguage: BATCH_AUTOMATIC_LANGUAGE_SUPPORT[provider],
        upstreamModel: model,
      },
    ])
  );

export const mapRealtimeAsrModels = <
  TProvider extends RealtimeAsrProviderId,
  const TModels extends readonly string[],
>(
  provider: TProvider,
  models: TModels,
  supportedLanguagesByModel: Record<TModels[number], readonly string[]>
): Record<string, RealtimeAsrModelEntry> =>
  Object.fromEntries(
    models.map((model) => [
      `${provider}-${model}`,
      {
        provider,
        supportedLanguages: supportedLanguagesByModel[model as TModels[number]],
        supportsAutomaticLanguage:
          REALTIME_AUTOMATIC_LANGUAGE_SUPPORT[provider],
        upstreamModel: model,
      },
    ])
  );
