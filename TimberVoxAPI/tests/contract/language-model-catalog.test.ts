import { describe, expect, it } from "vitest";

import { publicModelCatalog } from "../../src/ai/models/catalog";
import { intelligenceDisplayScore } from "../../src/routes/models";

describe("language model catalog", () => {
  it("converts the 100-point source index to a stable 10-point display score", () => {
    expect(intelligenceDisplayScore(30)).toBe(3);
    expect(intelligenceDisplayScore(41.7)).toBe(4.2);
    expect(intelligenceDisplayScore(11)).toBe(1.1);
  });

  it("exposes only the three current Mistral aliases", () => {
    const mistralModels = publicModelCatalog()
      .filter(
        (model) => model.kind === "language" && model.provider === "mistral"
      )
      .map((model) => model.id);

    expect(mistralModels).toEqual([
      "mistral-mistral-large-latest",
      "mistral-mistral-medium-latest",
      "mistral-mistral-small-latest",
    ]);
  });

  it("publishes the enforced reasoning profile and selected intelligence data", () => {
    const models = publicModelCatalog().filter(
      (model) => model.kind === "language"
    );
    const sonnet = models.find(
      (model) => model.id === "anthropic-claude-sonnet-5"
    );
    const mistralLarge = models.find(
      (model) => model.id === "mistral-mistral-large-latest"
    );
    const mistralMedium = models.find(
      (model) => model.id === "mistral-mistral-medium-latest"
    );
    const mistralSmall = models.find(
      (model) => model.id === "mistral-mistral-small-latest"
    );

    expect(sonnet).toMatchObject({
      intelligence: {
        index: 41.7,
        profile: "claude-sonnet-5-non-reasoning",
        source: "artificial-analysis",
        sourceVersion: "4.1",
      },
      reasoningProfile: "none",
    });
    expect(mistralLarge).toMatchObject({
      intelligence: {
        index: 16,
        profile: "mistral-large-3-non-reasoning",
      },
      reasoningProfile: "none",
    });
    expect(mistralSmall).toMatchObject({
      intelligence: {
        index: 11,
        profile: "mistral-small-3-2-non-reasoning",
      },
      reasoningProfile: "none",
    });
    expect(mistralMedium).toMatchObject({
      intelligence: {
        index: 30,
        profile: "mistral-medium-3-5-reasoning",
      },
      reasoningProfile: "none",
    });
    expect(models.map((model) => model.id)).not.toEqual(
      expect.arrayContaining([
        "anthropic-claude-fable-5",
        "anthropic-claude-opus-4-8",
        "openai-gpt-5.4-pro",
      ])
    );
    expect(models.every((model) => model.reasoningProfile)).toBe(true);
  });
});
