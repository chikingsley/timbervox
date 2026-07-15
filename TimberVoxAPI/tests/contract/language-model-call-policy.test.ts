import { describe, expect, it } from "vitest";

import { LANGUAGE_MODEL_MAP } from "../../src/ai/models/language-models";
import { enforceLanguageModelCallPolicy } from "../../src/ai/text/call-policy";

describe("language-model call policy", () => {
  it("assigns a fixed fast reasoning profile to every public route", () => {
    const profiles = Object.fromEntries(
      Object.entries(LANGUAGE_MODEL_MAP).map(([id, route]) => [
        id,
        route.callPolicy.reasoningProfile,
      ])
    );

    expect(profiles).toMatchObject({
      "anthropic-claude-sonnet-5": "none",
      "cerebras-gpt-oss-120b": "low",
      "cerebras-zai-glm-4.7": "none",
      "google-gemini-3.1-flash-lite": "minimal",
      "groq-openai/gpt-oss-20b": "low",
      "groq-openai/gpt-oss-120b": "low",
      "groq-qwen/qwen3.6-27b": "none",
      "mistral-mistral-small-latest": "none",
      "openai-gpt-5.5": "none",
      "zai-glm-5.2": "none",
    });
    expect(Object.keys(profiles)).toHaveLength(
      Object.keys(LANGUAGE_MODEL_MAP).length
    );
  });

  it("prevents a caller from overriding the route reasoning policy", () => {
    const result = enforceLanguageModelCallPolicy({
      callerProviderOptions: {
        anthropic: {
          customOption: "preserved",
          effort: "high",
          thinking: { type: "adaptive" },
        },
      },
      callerTemperature: 0,
      route: LANGUAGE_MODEL_MAP["anthropic-claude-sonnet-5"],
    });

    expect(result).toEqual({
      providerOptions: {
        anthropic: {
          customOption: "preserved",
          thinking: { type: "disabled" },
        },
      },
      temperature: 0,
    });
  });

  it("omits caller temperature for the minimum reasoning-only profile", () => {
    const result = enforceLanguageModelCallPolicy({
      callerProviderOptions: undefined,
      callerTemperature: 0,
      route: LANGUAGE_MODEL_MAP["google-gemini-3.1-flash-lite"],
    });

    expect(result.temperature).toBeUndefined();
    expect(result.providerOptions).toMatchObject({
      google: { thinkingConfig: { thinkingLevel: "minimal" } },
    });
  });
});
