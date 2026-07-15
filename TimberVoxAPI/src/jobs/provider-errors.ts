import { normalizeProviderFailure } from "../ai/provider-failure";

export class TransientProviderError extends Error {
  readonly retryDelaySeconds: number;

  constructor(message: string, delaySeconds: number) {
    super(message);
    this.name = "TransientProviderError";
    this.retryDelaySeconds = delaySeconds;
  }
}

export const isTransientProviderError = (error: unknown): boolean =>
  normalizeProviderFailure(error).retryable;

export const retryDelaySeconds = (attempts: number): number => {
  const attempt = Math.max(1, attempts);
  return Math.min(60 * 2 ** (attempt - 1), 900);
};

export const providerErrorMessage = (error: unknown): string =>
  normalizeProviderFailure(error).message;
