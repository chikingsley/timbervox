import type { Env } from "../bindings";
import { secretsEqual, sha256Hex } from "./crypto";

export interface AuthSession {
  credentialId: string;
  userId: string;
}

interface CredentialRow {
  credential_id: string;
  user_id: string;
}

const bearerPattern = /^Bearer\s+(.+)$/i;
const configuredKeySeparatorPattern = /[,\n]/;

const configuredAPIKeys = (value: string | undefined): string[] => {
  if (!value) {
    return [];
  }
  try {
    const parsed: unknown = JSON.parse(value);
    if (Array.isArray(parsed)) {
      return parsed.filter(
        (candidate): candidate is string =>
          typeof candidate === "string" && candidate.length > 0
      );
    }
  } catch {
    // A comma- or newline-delimited secret is also accepted for easy rotation.
  }
  return value
    .split(configuredKeySeparatorPattern)
    .map((candidate) => candidate.trim())
    .filter((candidate) => candidate.length > 0);
};

const matchesConfiguredKey = async (
  provided: string,
  configured: string[]
): Promise<boolean> => {
  const comparisons = await Promise.all(
    configured.map((candidate) => secretsEqual(provided, candidate))
  );
  return comparisons.includes(true);
};

const ensureStaticKeyIdentity = async (
  env: Env,
  credentialHash: string
): Promise<AuthSession> => {
  const suffix = credentialHash.slice(0, 32);
  const proposedUserId = `usr_key_${suffix}`;
  const proposedCredentialId = `key_${suffix}`;
  const now = new Date().toISOString();

  await env.DB.batch([
    env.DB.prepare(
      `INSERT OR IGNORE INTO users
        (id, email, display_name, created_at, updated_at)
       VALUES (?, ?, 'Static API key', ?, ?)`
    ).bind(proposedUserId, `${suffix}@api-key.timbervox.invalid`, now, now),
    env.DB.prepare(
      `INSERT OR IGNORE INTO api_credentials
        (id, user_id, label, credential_hash, status, created_at, last_seen_at)
       VALUES (?, ?, 'Static Worker API key', ?, 'active', ?, ?)`
    ).bind(proposedCredentialId, proposedUserId, credentialHash, now, now),
    env.DB.prepare(
      `UPDATE api_credentials
          SET status = 'active',
              revoked_at = NULL,
              last_seen_at = ?
        WHERE credential_hash = ?`
    ).bind(now, credentialHash),
  ]);

  const row = await env.DB.prepare(
    `SELECT id AS credential_id, user_id
       FROM api_credentials
      WHERE credential_hash = ?`
  )
    .bind(credentialHash)
    .first<CredentialRow>();
  if (!row) {
    throw new Error("failed to register configured API key");
  }
  return {
    credentialId: row.credential_id,
    userId: row.user_id,
  };
};

export const authenticateCredential = async (
  env: Env,
  authorization: string | null | undefined
): Promise<AuthSession | null> => {
  const token = authorization?.match(bearerPattern)?.[1];
  if (!token) {
    return null;
  }
  const configured = configuredAPIKeys(env.TIMBERVOX_API_KEYS);
  if (!(await matchesConfiguredKey(token, configured))) {
    return null;
  }
  return ensureStaticKeyIdentity(env, await sha256Hex(token));
};
