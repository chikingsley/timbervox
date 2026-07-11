import { describe, expect, it } from "vitest";

import { runTextTransform } from "../../src/ai/text-transform";
import { liveEnv, liveTestsEnabled } from "./env";

interface TextCase {
  envKey: string;
  model: string;
}

// The production request itself stops at ten seconds. The small harness margin
// lets Vitest report the provider error instead of replacing it with a test
// timeout.
const liveTestTimeoutMs = 10_500;

const cases: TextCase[] = [
  { envKey: "MISTRAL_API_KEY", model: "mistral-mistral-small-latest" },
  { envKey: "OPENAI_API_KEY", model: "openai-gpt-5.5" },
  {
    envKey: "GOOGLE_GENERATIVE_AI_API_KEY",
    model: "google-gemini-3.1-flash-lite",
  },
];

describe("live text transform providers", () => {
  for (const testCase of cases) {
    it(
      `transforms text with ${testCase.model}`,
      async ({ skip }) => {
        if (!(liveTestsEnabled && process.env[testCase.envKey])) {
          skip("live tests disabled or provider credential unavailable");
        }
        const result = await runTextTransform(liveEnv(), {
          messages: [
            {
              content:
                "Clean up this transcript as a short message. Return only the cleaned text.\n\nhello comma this is a live test period thank you",
              role: "user",
            },
          ],
          model: testCase.model,
        });

        expect(result.model).toBe(testCase.model);
        expect(result.text.trim().length).toBeGreaterThan(0);
      },
      liveTestTimeoutMs
    );
  }
});
