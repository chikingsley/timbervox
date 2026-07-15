import type { SharedV4ProviderOptions } from "@ai-sdk/provider";

export type LanguageModelProviderId =
  | "anthropic"
  | "cerebras"
  | "deepseek"
  | "google"
  | "groq"
  | "mistral"
  | "openai"
  | "zai";

export type BatchAsrProviderId = "deepgram" | "elevenlabs" | "mistral";

export type RealtimeAsrProviderId = "deepgram" | "mistral";

export type LanguageModelReasoningProfile =
  | "low"
  | "medium"
  | "minimal"
  | "none";

export interface LanguageModelCallPolicy {
  providerOptions?: SharedV4ProviderOptions;
  reasoningProfile: LanguageModelReasoningProfile;
}

export interface LanguageModelIntelligence {
  index: number;
  measuredAt: string;
  profile: string;
  source: "artificial-analysis";
  sourceVersion: string;
}

export type ModelMetricSource =
  | "fluid-audio"
  | "provider-published"
  | "route-capability"
  | "timbervox-benchmark";

export interface ModelAccuracyPresentation {
  benchmark: string;
  metric: "wer";
  source: ModelMetricSource;
  value: number;
}

export interface ModelSpeedPresentation {
  approximate: boolean;
  kind: "effective-tps" | "realtime" | "rtfx";
  measuredAt?: string;
  profile?: string;
  source: ModelMetricSource;
  value?: number;
}

export interface LanguageModelEntry {
  callPolicy: LanguageModelCallPolicy;
  intelligence?: LanguageModelIntelligence;
  provider: LanguageModelProviderId;
  providerModelId: `${LanguageModelProviderId}:${string}`;
  upstreamModel: string;
}

export interface BatchAsrModelEntry {
  acceptedOptions: readonly AcceptedAsrOptionName[];
  provider: BatchAsrProviderId;
  supportedLanguages: readonly string[];
  supportsAutomaticLanguage: boolean;
  upstreamModel: string;
}

export interface RealtimeAsrModelEntry {
  acceptedOptions: readonly AcceptedAsrOptionName[];
  provider: RealtimeAsrProviderId;
  supportedLanguages: readonly string[];
  supportsAutomaticLanguage: boolean;
  upstreamModel: string;
}

export type PublicModelKind = "language" | "transcription";
export type AsrTransport = "batch" | "realtime";
export type AcceptedAsrOptionName = string;

export interface PublicAsrRouteSpec {
  acceptedOptions: readonly AcceptedAsrOptionName[];
  model: string;
  provider: BatchAsrProviderId | RealtimeAsrProviderId;
  supportedLanguages: readonly string[];
  supportsAutomaticLanguage: boolean;
  supportsDiarization: boolean;
  upstreamModel: string;
}

interface PublicLanguageModelSpec {
  acceptedOptions?: never;
  accuracy?: never;
  id: string;
  intelligence?: LanguageModelIntelligence;
  kind: "language";
  provider: LanguageModelProviderId;
  reasoningProfile: LanguageModelReasoningProfile;
  routes?: never;
  speed?: ModelSpeedPresentation;
  supportedLanguages?: never;
  transports?: never;
  upstreamModel: string;
}

export interface PublicTranscriptionModelSpec {
  acceptedOptions: Partial<
    Record<AsrTransport, readonly AcceptedAsrOptionName[]>
  >;
  accuracy?: ModelAccuracyPresentation;
  id: string;
  kind: "transcription";
  provider: BatchAsrProviderId | RealtimeAsrProviderId;
  routes: Partial<Record<AsrTransport, PublicAsrRouteSpec>>;
  speed?: ModelSpeedPresentation;
  supportedLanguages: readonly string[];
  transports: readonly AsrTransport[];
  upstreamModel: string;
}

export type PublicModelSpec =
  | PublicLanguageModelSpec
  | PublicTranscriptionModelSpec;
