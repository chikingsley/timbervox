import { recordUsageEvent } from "../accounting/usage";
import type { RealtimeAsrProviderId } from "../ai/models/types";
import {
  finalRealtimeTranscript,
  type RealtimeTranscriptEvent,
} from "../ai/realtime/normalize";
import type { Env } from "../bindings";

export interface RealtimeResultConfig {
  clientId: string;
  credentialId: string;
  language: string | null;
  model: string;
  provider: RealtimeAsrProviderId;
  sampleRate: number | null;
  sessionId: string;
  upstreamModel: string;
  userId: string;
}

export interface RealtimeResultInput {
  audioBytes: number;
  endedAt: string;
  error?: string | null;
  events: RealtimeTranscriptEvent[];
  messageCount: number;
  startedAt: string;
  status: "failed" | "succeeded";
}

export interface RealtimePersistResult {
  transcript: string;
  transcriptJsonKey: string;
  transcriptTextKey: string;
}

const contentTypeJson = "application/json";
const contentTypeText = "text/plain; charset=utf-8";

const audioSeconds = (
  audioBytes: number,
  sampleRate: number | null
): number | null => {
  if (audioBytes <= 0 || !sampleRate) {
    return null;
  }
  return audioBytes / 2 / sampleRate;
};

export const persistRealtimeResult = async (
  env: Env,
  config: RealtimeResultConfig,
  input: RealtimeResultInput
): Promise<RealtimePersistResult> => {
  const transcript = finalRealtimeTranscript(config.provider, input.events);
  const prefix = `realtime/${config.userId}/${config.sessionId}`;
  const transcriptJsonKey = `${prefix}/transcript.json`;
  const transcriptTextKey = `${prefix}/transcript.txt`;
  const resultJson = {
    audio_bytes: input.audioBytes,
    audio_seconds: audioSeconds(input.audioBytes, config.sampleRate),
    client_id: config.clientId,
    credential_id: config.credentialId,
    ended_at: input.endedAt,
    error: input.error ?? null,
    events: input.events,
    language: config.language,
    message_count: input.messageCount,
    model: config.model,
    provider: config.provider,
    session_id: config.sessionId,
    started_at: input.startedAt,
    status: input.status,
    transcript,
    upstream_model: config.upstreamModel,
    user_id: config.userId,
  };

  await env.ARTIFACTS.put(transcriptJsonKey, JSON.stringify(resultJson), {
    httpMetadata: { contentType: contentTypeJson },
  });
  await env.ARTIFACTS.put(transcriptTextKey, transcript, {
    httpMetadata: { contentType: contentTypeText },
  });
  await env.DB.prepare(
    `INSERT INTO realtime_sessions
      (id, client_id, credential_id, owner_user_id, provider, model,
       upstream_model, language, status,
       transcript, transcript_json_key, transcript_text_key, audio_bytes,
       audio_seconds, message_count, error, started_at, ended_at, created_at,
       updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       client_id = excluded.client_id,
       credential_id = excluded.credential_id,
       owner_user_id = excluded.owner_user_id,
       provider = excluded.provider,
       model = excluded.model,
       upstream_model = excluded.upstream_model,
       language = excluded.language,
       status = excluded.status,
       transcript = excluded.transcript,
       transcript_json_key = excluded.transcript_json_key,
       transcript_text_key = excluded.transcript_text_key,
       audio_bytes = excluded.audio_bytes,
       audio_seconds = excluded.audio_seconds,
       message_count = excluded.message_count,
       error = excluded.error,
       ended_at = excluded.ended_at,
       updated_at = excluded.updated_at`
  )
    .bind(
      config.sessionId,
      config.clientId,
      config.credentialId,
      config.userId,
      config.provider,
      config.model,
      config.upstreamModel,
      config.language,
      input.status,
      transcript,
      transcriptJsonKey,
      transcriptTextKey,
      input.audioBytes,
      audioSeconds(input.audioBytes, config.sampleRate),
      input.messageCount,
      input.error ?? null,
      input.startedAt,
      input.endedAt,
      input.startedAt,
      input.endedAt
    )
    .run();

  await recordUsageEvent(env, {
    asrSeconds: audioSeconds(input.audioBytes, config.sampleRate),
    clientId: config.clientId,
    error: input.error ?? null,
    kind: "realtime_asr",
    metadata: { session_id: config.sessionId },
    model: config.model,
    provider: config.provider,
    route: "/v1/realtime",
    status: input.status === "succeeded" ? 200 : 500,
    upstreamModel: config.upstreamModel,
    userId: config.userId,
  });

  return { transcript, transcriptJsonKey, transcriptTextKey };
};
