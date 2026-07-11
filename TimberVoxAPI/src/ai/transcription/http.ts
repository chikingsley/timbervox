import type { ZodType } from "zod";

class TranscriptionProviderError extends Error {
  readonly body: unknown;
  readonly provider: string;
  readonly status: number;

  constructor(
    provider: string,
    status: number,
    body: unknown,
    message = `${provider} transcription failed ${status}`
  ) {
    super(message);
    this.name = "TranscriptionProviderError";
    this.body = body;
    this.provider = provider;
    this.status = status;
  }
}

export const readProviderResponse = async <Result>(
  provider: string,
  response: Response,
  schema: ZodType<Result>
): Promise<Result> => {
  const body = await readJson(response);
  if (!response.ok) {
    throw new TranscriptionProviderError(provider, response.status, body);
  }
  return schema.parse(body);
};

const readJson = async (response: Response): Promise<unknown> => {
  const text = await response.text();
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};
