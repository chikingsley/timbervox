import type { SharedV4ProviderOptions } from "@ai-sdk/provider";
import type { generateText } from "ai";

import type { LanguageModelEntry } from "../models/types";

type ProviderOptions = Parameters<typeof generateText>[0]["providerOptions"];

const reasoningOptionNames = new Set([
  "effort",
  "reasoning",
  "reasoning_effort",
  "reasoningEffort",
  "thinking",
  "thinking_config",
  "thinkingConfig",
]);

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const withoutCallerReasoning = (
  options: ProviderOptions
): SharedV4ProviderOptions =>
  Object.fromEntries(
    Object.entries(options ?? {}).flatMap(([provider, value]) => {
      if (!isRecord(value)) {
        return [];
      }
      return [
        [
          provider,
          Object.fromEntries(
            Object.entries(value).filter(
              ([name]) => !reasoningOptionNames.has(name)
            )
          ),
        ],
      ];
    })
  ) as SharedV4ProviderOptions;

export const enforceLanguageModelCallPolicy = (input: {
  callerProviderOptions: ProviderOptions;
  callerTemperature: number | undefined;
  route: LanguageModelEntry;
}): {
  providerOptions: ProviderOptions;
  temperature: number | undefined;
} => {
  const callerOptions = withoutCallerReasoning(input.callerProviderOptions);
  const enforcedOptions = input.route.callPolicy.providerOptions ?? {};
  const providerOptions = Object.fromEntries(
    [
      ...new Set([
        ...Object.keys(callerOptions),
        ...Object.keys(enforcedOptions),
      ]),
    ].map((provider) => [
      provider,
      {
        ...callerOptions[provider],
        ...enforcedOptions[provider],
      },
    ])
  ) as SharedV4ProviderOptions;
  return {
    providerOptions,
    temperature:
      input.route.callPolicy.reasoningProfile === "none"
        ? input.callerTemperature
        : undefined,
  };
};
