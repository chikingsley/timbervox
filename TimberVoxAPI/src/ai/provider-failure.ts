import { APICallError } from "ai";

export type ProviderFailureCategory =
  | "authentication"
  | "empty_output"
  | "invalid_request"
  | "network"
  | "rate_limited"
  | "timeout"
  | "unavailable"
  | "unknown";

export interface ProviderFailure {
  category: ProviderFailureCategory;
  message: string;
  providerCode?: string;
  retryAfterMs?: number;
  retryable: boolean;
  statusCode?: number;
}

const durationPattern = /^(\d+(?:\.\d+)?)(ms|s|m)?$/;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const stringValue = (value: unknown): string | undefined =>
  typeof value === "string" && value.length > 0 ? value : undefined;

const errorChain = (error: unknown): unknown[] => {
  const chain: unknown[] = [];
  const visited = new Set<unknown>();
  let current: unknown = error;
  while (current !== undefined && current !== null && chain.length < 8) {
    if (visited.has(current)) {
      break;
    }
    visited.add(current);
    chain.push(current);
    current = isRecord(current) ? current.cause : undefined;
  }
  return chain;
};

const statusFromError = (chain: readonly unknown[]): number | undefined => {
  for (const error of chain) {
    if (APICallError.isInstance(error) && error.statusCode !== undefined) {
      return error.statusCode;
    }
    if (!isRecord(error)) {
      continue;
    }
    for (const key of ["status", "statusCode", "status_code"] as const) {
      const value = Number(error[key]);
      if (Number.isInteger(value)) {
        return value;
      }
    }
  }
};

const apiCallFromError = (
  chain: readonly unknown[]
): APICallError | undefined =>
  chain.find((error): error is APICallError => APICallError.isInstance(error));

const parseResponseBody = (body: string | undefined): unknown => {
  if (!body) {
    return;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    parsed = undefined;
  }
  return parsed;
};

const errorData = (value: unknown): Record<string, unknown> | undefined => {
  if (!isRecord(value)) {
    return;
  }
  return isRecord(value.error) ? value.error : value;
};

const providerCodeFromData = (value: unknown): string | undefined => {
  const data = errorData(value);
  if (!data) {
    return;
  }
  return (
    stringValue(data.code) ??
    stringValue(data.type) ??
    stringValue(data.error_code)
  );
};

const messageFromData = (value: unknown): string | undefined => {
  const data = errorData(value);
  return data ? stringValue(data.message) : undefined;
};

const messageFromError = (
  chain: readonly unknown[],
  apiCall: APICallError | undefined
): string => {
  const providerData =
    apiCall?.data ?? parseResponseBody(apiCall?.responseBody);
  const providerMessage = messageFromData(providerData);
  if (providerMessage) {
    return providerMessage;
  }
  const error = chain.find((item): item is Error => item instanceof Error);
  return error?.message ?? String(chain[0]);
};

const lowerCaseHeaders = (
  headers: Record<string, string> | undefined
): Record<string, string> =>
  Object.fromEntries(
    Object.entries(headers ?? {}).map(([name, value]) => [
      name.toLowerCase(),
      value,
    ])
  );

const durationMs = (value: string): number | undefined => {
  const trimmed = value.trim().toLowerCase();
  const matched = durationPattern.exec(trimmed);
  if (!matched) {
    return;
  }
  const amount = Number(matched[1]);
  const unit = matched[2] ?? "s";
  if (!Number.isFinite(amount)) {
    return;
  }
  if (unit === "ms") {
    return Math.round(amount);
  }
  if (unit === "m") {
    return Math.round(amount * 60_000);
  }
  return Math.round(amount * 1000);
};

const retryAfterFromHeaders = (
  headers: Record<string, string> | undefined,
  nowMs: number
): number | undefined => {
  const normalized = lowerCaseHeaders(headers);
  const retryAfterMs = normalized["retry-after-ms"];
  if (retryAfterMs) {
    return durationMs(`${retryAfterMs}ms`);
  }

  const retryAfter = normalized["retry-after"];
  if (retryAfter) {
    const relative = durationMs(retryAfter);
    if (relative !== undefined) {
      return relative;
    }
    const absolute = Date.parse(retryAfter);
    if (Number.isFinite(absolute)) {
      return Math.max(0, absolute - nowMs);
    }
  }
};

const classify = (input: {
  apiCall: APICallError | undefined;
  message: string;
  statusCode: number | undefined;
}): ProviderFailureCategory => {
  const { apiCall, message, statusCode } = input;
  if (statusCode === 429) {
    return "rate_limited";
  }
  if (statusCode === 408) {
    return "timeout";
  }
  if (statusCode === 401 || statusCode === 403) {
    return "authentication";
  }
  if (
    statusCode === 400 ||
    statusCode === 404 ||
    statusCode === 405 ||
    statusCode === 422
  ) {
    return "invalid_request";
  }
  if (statusCode === 409 || statusCode === 425 || (statusCode ?? 0) >= 500) {
    return "unavailable";
  }

  const normalized = message.toLowerCase();
  if (
    normalized.includes("429") ||
    normalized.includes("rate limit") ||
    normalized.includes("too many requests")
  ) {
    return "rate_limited";
  }
  if (
    normalized.includes("timed out") ||
    normalized.includes("timeout") ||
    normalized.includes("aborted due to timeout")
  ) {
    return "timeout";
  }
  if (
    normalized.includes("connection reset") ||
    normalized.includes("econnreset") ||
    normalized.includes("fetch failed") ||
    normalized.includes("network")
  ) {
    return "network";
  }
  if (normalized.includes("overloaded") || normalized.includes("temporarily")) {
    return "unavailable";
  }
  if (apiCall?.isRetryable) {
    return "unavailable";
  }
  return "unknown";
};

const categoryIsRetryable = (category: ProviderFailureCategory): boolean =>
  category === "network" ||
  category === "rate_limited" ||
  category === "timeout" ||
  category === "unavailable";

export const normalizeProviderFailure = (
  error: unknown,
  nowMs = Date.now()
): ProviderFailure => {
  const chain = errorChain(error);
  const apiCall = apiCallFromError(chain);
  const statusCode = statusFromError(chain);
  const message = messageFromError(chain, apiCall);
  const category = classify({ apiCall, message, statusCode });
  const data = apiCall?.data ?? parseResponseBody(apiCall?.responseBody);
  return {
    category,
    message,
    providerCode: providerCodeFromData(data),
    retryAfterMs: retryAfterFromHeaders(apiCall?.responseHeaders, nowMs),
    retryable: categoryIsRetryable(category),
    statusCode,
  };
};
