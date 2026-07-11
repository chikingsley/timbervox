import { AwsClient } from "aws4fetch";

import type { Env } from "../bindings";

const PRESIGNED_URL_TTL_SECONDS = 15 * 60;

interface R2SigningConfig {
  accessKeyId: string;
  accountId: string;
  bucketName: string;
  secretAccessKey: string;
}

export const signR2GetUrl = async (env: Env, key: string): Promise<string> =>
  signR2Url(env, key, { method: "GET" });

export const signR2PutUrl = async (
  env: Env,
  key: string,
  input: { contentType?: string; partNumber?: number; uploadId?: string } = {}
): Promise<{ headers: Record<string, string>; url: string }> => {
  const headers: Record<string, string> = {};
  if (input.contentType) {
    headers["content-type"] = input.contentType;
  }
  const url = await signR2Url(env, key, {
    headers,
    method: "PUT",
    query:
      input.partNumber === undefined || input.uploadId === undefined
        ? undefined
        : {
            partNumber: String(input.partNumber),
            uploadId: input.uploadId,
          },
  });
  return { headers, url };
};

const signR2Url = async (
  env: Env,
  key: string,
  input: {
    headers?: Record<string, string>;
    method: "GET" | "PUT";
    query?: Record<string, string>;
  }
): Promise<string> => {
  const config = signingConfig(env);
  const url = objectUrl(config, key);
  for (const [name, value] of Object.entries(input.query ?? {})) {
    url.searchParams.set(name, value);
  }
  url.searchParams.set("X-Amz-Expires", String(PRESIGNED_URL_TTL_SECONDS));
  const client = new AwsClient({
    accessKeyId: config.accessKeyId,
    secretAccessKey: config.secretAccessKey,
  });
  const signed = await client.sign(url, {
    aws: { allHeaders: true, signQuery: true },
    headers: input.headers,
    method: input.method,
  });
  return signed.url;
};

const signingConfig = (env: Env): R2SigningConfig => {
  if (!env.CLOUDFLARE_ACCOUNT_ID) {
    throw new Error("missing CLOUDFLARE_ACCOUNT_ID");
  }
  if (!env.R2_BUCKET_NAME) {
    throw new Error("missing R2_BUCKET_NAME");
  }
  if (!env.R2_ACCESS_KEY_ID) {
    throw new Error("missing R2_ACCESS_KEY_ID");
  }
  if (!env.R2_SECRET_ACCESS_KEY) {
    throw new Error("missing R2_SECRET_ACCESS_KEY");
  }
  return {
    accessKeyId: env.R2_ACCESS_KEY_ID,
    accountId: env.CLOUDFLARE_ACCOUNT_ID,
    bucketName: env.R2_BUCKET_NAME,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY,
  };
};

const objectUrl = (config: R2SigningConfig, key: string): URL => {
  const encodedPath = [config.bucketName, ...key.split("/")]
    .map(encodeURIComponent)
    .join("/");
  return new URL(
    `https://${config.accountId}.r2.cloudflarestorage.com/${encodedPath}`
  );
};
