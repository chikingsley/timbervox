import { describe, expect, it } from "vitest";

import { TextStreamRequest } from "../../src/ai/text/service";
import {
  textStreamCompletedEvent,
  textStreamDeltaEvent,
  textStreamFailedEvent,
  textStreamStartedEvent,
} from "../../src/ai/text/stream-protocol";

describe("provider-neutral text streaming protocol", () => {
  it("emits an ordered provider-neutral success flow", () => {
    const started = textStreamStartedEvent({
      model: "mistral-mistral-medium-latest",
      provider: "mistral",
      sequence: 0,
      upstreamModel: "mistral-medium-latest",
    });
    const delta = textStreamDeltaEvent("Hello", 1);
    const completed = textStreamCompletedEvent({
      finishReason: "stop",
      model: "mistral-mistral-medium-latest",
      performance: {
        effective_output_tokens_per_second: 40,
        output_tokens_per_second: 80,
        response_time_ms: 500,
        step_time_ms: 500,
        time_to_first_output_ms: 250,
      },
      provider: "mistral",
      providerLatencyMs: 510,
      responseModelId: "mistral-medium-3.1",
      sequence: 2,
      upstreamModel: "mistral-medium-latest",
      usage: {
        input_tokens: 12,
        output_tokens: 20,
        reasoning_tokens: 2,
        text_tokens: 18,
        total_tokens: 32,
      },
      warnings: undefined,
    });

    expect([started.type, delta.type, completed.type]).toEqual([
      "stream.started",
      "text.delta",
      "stream.completed",
    ]);
    expect([started.sequence, delta.sequence, completed.sequence]).toEqual([
      0, 1, 2,
    ]);
    expect(completed.usage.text_tokens).toBe(18);
    expect(completed).not.toHaveProperty("choices");
    expect(completed).not.toHaveProperty("candidates");
  });

  it("uses one normalized terminal failure", () => {
    const failed = textStreamFailedEvent({
      category: "timeout",
      code: "provider_error",
      message: "upstream timed out",
      model: "mistral-mistral-medium-latest",
      provider: "mistral",
      providerCode: "request_timeout",
      providerLatencyMs: 10_000,
      retryAfterMs: 2000,
      retryable: true,
      sequence: 3,
      statusCode: 408,
      upstreamModel: "mistral-medium-latest",
    });

    expect(failed).toMatchObject({
      error: {
        category: "timeout",
        code: "provider_error",
        provider_code: "request_timeout",
        retry_after_ms: 2000,
        retryable: true,
        status_code: 408,
      },
      protocol_version: 1,
      type: "stream.failed",
    });
  });

  it("marks a reasoning-only completion as a permanent empty output", () => {
    const failed = textStreamFailedEvent({
      category: "empty_output",
      code: "empty_output",
      message: "Provider completed without emitting user-visible text",
      model: "openai-gpt-5.4",
      provider: "openai",
      providerLatencyMs: 500,
      retryable: false,
      sequence: 1,
      upstreamModel: "gpt-5.4",
    });

    expect(failed.error).toMatchObject({
      category: "empty_output",
      code: "empty_output",
      retryable: false,
    });
  });

  it("allows text controls but rejects structured output requests", () => {
    const request = {
      maxOutputTokens: 64,
      messages: [{ content: "Hello", role: "user" }],
      model: "mistral-mistral-medium-latest",
      temperature: 0,
    };

    expect(TextStreamRequest.safeParse(request).success).toBe(true);
    expect(
      TextStreamRequest.safeParse({
        ...request,
        output: { schema: { type: "object" }, type: "object" },
      }).success
    ).toBe(false);
  });
});
