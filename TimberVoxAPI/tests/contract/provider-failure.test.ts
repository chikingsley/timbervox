import { APICallError } from "ai";
import { describe, expect, it } from "vitest";

import { normalizeProviderFailure } from "../../src/ai/provider-failure";

const apiError = (input: {
  data?: unknown;
  isRetryable?: boolean;
  responseHeaders?: Record<string, string>;
  statusCode?: number;
}) =>
  new APICallError({
    data: input.data,
    isRetryable: input.isRetryable,
    message: "provider request failed",
    requestBodyValues: {},
    responseHeaders: input.responseHeaders,
    statusCode: input.statusCode,
    url: "https://provider.example/v1/chat",
  });

describe("provider failure normalization", () => {
  it("preserves rate-limit metadata and the provider delay", () => {
    expect(
      normalizeProviderFailure(
        apiError({
          data: { error: { code: "quota_exceeded", message: "Slow down" } },
          responseHeaders: { "Retry-After": "1.5" },
          statusCode: 429,
        })
      )
    ).toEqual({
      category: "rate_limited",
      message: "Slow down",
      providerCode: "quota_exceeded",
      retryAfterMs: 1500,
      retryable: true,
      statusCode: 429,
    });
  });

  it("marks invalid requests as permanent", () => {
    expect(
      normalizeProviderFailure(
        apiError({
          data: { error: { code: "invalid_model", message: "Bad model" } },
          isRetryable: true,
          statusCode: 400,
        })
      )
    ).toMatchObject({
      category: "invalid_request",
      providerCode: "invalid_model",
      retryable: false,
      statusCode: 400,
    });
  });

  it("does not create a retry storm for an unknown error", () => {
    expect(
      normalizeProviderFailure(new Error("unexpected provider shape"))
    ).toMatchObject({
      category: "unknown",
      retryable: false,
    });
  });

  it("recognizes the Worker timeout error", () => {
    expect(
      normalizeProviderFailure(
        new Error("The operation was aborted due to timeout")
      )
    ).toMatchObject({
      category: "timeout",
      retryable: true,
    });
  });
});
