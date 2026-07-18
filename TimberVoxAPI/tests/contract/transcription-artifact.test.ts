import { describe, expect, it } from "vitest";
import { z } from "zod";

import {
  batchTranscriptionArtifact,
  TranscriptionArtifactSchema,
} from "../../src/ai/transcription/artifact";
import { readProviderResponse } from "../../src/ai/transcription/http";
import { app, openApiDocumentConfig } from "../../src/index";

describe("transcription artifact contract", () => {
  it("retains fields outside the normalization schema", async () => {
    const response = Response.json({
      future_provider_field: { nested: [1, 2, 3] },
      text: "Hello",
    });
    const result = await readProviderResponse(
      "Test",
      response,
      z.object({ text: z.string() })
    );

    expect(result.parsed).toEqual({ text: "Hello" });
    expect(result.raw).toMatchObject({
      future_provider_field: { nested: [1, 2, 3] },
    });
  });

  it("preserves provider-native scores beside normalized values", () => {
    const artifact = batchTranscriptionArtifact({
      completedAt: "2026-07-14T12:00:02.000Z",
      model: "elevenlabs-scribe-v2",
      provider: "elevenlabs",
      providerLatencyMs: 500,
      queueDelayMs: 25,
      requestedLanguage: "en",
      result: {
        audioEvents: [],
        collections: {
          audioEvents: { availability: "available", source: "provider" },
          segments: { availability: "available", source: "derived" },
          speakerTurns: { availability: "available", source: "derived" },
          tokens: { availability: "available", source: "provider" },
          words: { availability: "available", source: "provider" },
        },
        durationSeconds: 1.5,
        language: "en",
        languageConfidence: 0.98,
        providerMetadata: { languageProbability: 0.98 },
        providerResponse: {
          language_code: "en",
          text: "Hello",
          words: [
            {
              end: 1.5,
              logprob: -0.1,
              start: 1,
              text: "Hello",
              type: "word",
            },
          ],
        },
        segments: [],
        speakerTurns: [],
        text: "Hello",
        tokens: [
          {
            endSeconds: 1.5,
            kind: "word",
            scores: { logProbability: -0.1 },
            startSeconds: 1,
            text: "Hello",
          },
        ],
        usage: {},
        warnings: [],
        words: [
          {
            endSeconds: 1.5,
            scores: { confidence: Math.exp(-0.1), logProbability: -0.1 },
            startSeconds: 1,
            text: "Hello",
          },
        ],
      },
      runId: "job_contract",
      startedAt: "2026-07-14T12:00:00.000Z",
      upstreamModel: "scribe_v2",
    });

    expect(artifact.schema_version).toBe(2);
    expect(artifact.content.words.items[0]?.scores).toMatchObject({
      confidence: Math.exp(-0.1),
      log_probability: -0.1,
    });
    expect(artifact.provider_capture.response.payload).toMatchObject({
      words: [{ logprob: -0.1 }],
    });
    expect(artifact.metrics.realtime_speed_factor).toBe(3);
    expect(() =>
      TranscriptionArtifactSchema.parse({ ...artifact, schema_version: 1 })
    ).toThrow();
    expect(() =>
      TranscriptionArtifactSchema.parse({
        ...artifact,
        raw_transcript: "legacy",
      })
    ).toThrow();
  });

  it("publishes the artifact as the only successful job result schema", () => {
    const document = app.getOpenAPI31Document(openApiDocumentConfig) as {
      components?: {
        schemas?: Record<string, unknown>;
      };
    };
    const schemas = document.components?.schemas ?? {};
    const jobView = schemas.JobView as {
      properties?: Record<string, unknown>;
    };

    expect(schemas).toHaveProperty("TranscriptionArtifact");
    expect(jobView.properties?.result).toMatchObject({
      anyOf: expect.arrayContaining([
        { $ref: "#/components/schemas/TranscriptionArtifact" },
      ]),
    });
    expect(JSON.stringify(jobView.properties?.result)).not.toContain(
      "additionalProperties"
    );
  });
});
