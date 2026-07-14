import {
  experimental_streamTranscribe,
  type StreamTranscriptionResult,
  type TranscriptionStreamPart,
} from "ai";
import { z } from "zod";

import type { DeepgramRealtimeOptions } from "../ai/deepgram/realtime/client";
import type { RealtimeAsrProviderId } from "../ai/models/types";
import { createRealtimeTranscriptionModel } from "../ai/realtime/model";
import {
  finalRealtimeTranscript,
  type RealtimeTranscriptEvent,
  realtimeTranscriptEventFromStreamPart,
} from "../ai/realtime/normalize";
import {
  type RealtimeSessionTerminalEvent,
  sessionStartedEvent,
  terminalSessionEvent,
  transcriptProtocolEvent,
} from "../ai/realtime/protocol";
import type { Env } from "../bindings";
import {
  persistRealtimeResult,
  type RealtimePersistResult,
} from "./realtime-result";

interface RealtimeSessionConfig {
  clientId: string;
  credentialId: string;
  deepgram: DeepgramRealtimeOptions;
  encoding: string | null;
  language: string | null;
  model: string;
  provider: RealtimeAsrProviderId;
  sampleRate: number | null;
  sessionId: string;
  targetStreamingDelayMs: number | null;
  upstreamModel: string;
  userId: string;
}

const json = (value: unknown): string => JSON.stringify(value);

const RealtimeSessionConfigSchema = z
  .object({
    channels: z.number().int().positive().optional(),
    clientId: z.string(),
    credentialId: z.string(),
    deepgram: z
      .object({
        detectEntities: z.boolean().optional(),
        diarize: z.boolean().optional(),
        diarizeModel: z.enum(["latest", "v1"]).optional(),
        dictation: z.boolean().optional(),
        endpointing: z.string().optional(),
        fillerWords: z.boolean().optional(),
        interimResults: z.boolean().optional(),
        keyterm: z.array(z.string()).optional(),
        keywords: z.array(z.string()).optional(),
        mipOptOut: z.boolean().optional(),
        multichannel: z.boolean().optional(),
        numerals: z.boolean().optional(),
        profanityFilter: z.boolean().optional(),
        punctuate: z.boolean().optional(),
        redact: z.array(z.string()).optional(),
        replace: z.array(z.string()).optional(),
        search: z.array(z.string()).optional(),
        smartFormat: z.boolean().optional(),
        tag: z.array(z.string()).optional(),
        utteranceEndMs: z.number().int().positive().optional(),
        vadEvents: z.boolean().optional(),
        version: z.string().optional(),
      })
      .optional(),
    encoding: z.string().nullable().optional(),
    language: z.string().nullable().optional(),
    model: z.string(),
    provider: z.enum(["deepgram", "mistral"]),
    sampleRate: z.number().int().positive().nullable().optional(),
    sessionId: z.string(),
    targetStreamingDelayMs: z.number().int().positive().nullable().optional(),
    upstreamModel: z.string(),
    userId: z.string(),
  })
  .strict();

const configFromHeaders = (headers: Headers): RealtimeSessionConfig => {
  const rawConfig = headers.get("x-realtime-config");
  if (!rawConfig) {
    throw new Error("missing realtime config");
  }
  const config = RealtimeSessionConfigSchema.parse(JSON.parse(rawConfig));
  return {
    clientId: config.clientId,
    credentialId: config.credentialId,
    deepgram: {
      ...config.deepgram,
      channels: config.channels,
      encoding: config.encoding ?? undefined,
      language: config.language ?? undefined,
      sampleRate: config.sampleRate ?? undefined,
    },
    encoding: config.encoding ?? null,
    language: config.language ?? null,
    model: config.model,
    provider: config.provider,
    sampleRate: config.sampleRate ?? null,
    sessionId: config.sessionId,
    targetStreamingDelayMs: config.targetStreamingDelayMs ?? null,
    upstreamModel: config.upstreamModel,
    userId: config.userId,
  };
};

const closeSocket = (socket: WebSocket, code: number, reason: string): void => {
  try {
    socket.close(code, reason);
  } catch {
    // Socket was already closed.
  }
};

export class RealtimeSession {
  private audioInputWriter: WritableStreamDefaultWriter<
    string | Uint8Array
  > | null = null;
  private audioBytes = 0;
  private readonly env: Env;
  private eventSequence = 0;
  private messageCount = 0;
  private readonly state: DurableObjectState;
  private startedAt: string | null = null;
  private streamAbortController: AbortController | null = null;
  private streamConsumptionPromise: Promise<void> | null = null;
  private streamError: string | null = null;
  private streamResult: StreamTranscriptionResult | null = null;
  private terminalEventPromise: Promise<RealtimeSessionTerminalEvent> | null =
    null;
  private readonly transcriptEvents: RealtimeTranscriptEvent[] = [];

  constructor(state: DurableObjectState, env: Env) {
    this.env = env;
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    if (request.headers.get("upgrade")?.toLowerCase() !== "websocket") {
      return new Response("expected websocket upgrade", { status: 426 });
    }

    const config = configFromHeaders(request.headers);
    this.startedAt = new Date().toISOString();
    const [client, server] = Object.values(new WebSocketPair()) as [
      WebSocket,
      WebSocket,
    ];
    server.accept();

    await this.state.storage.put("session", {
      audioBytes: this.audioBytes,
      config,
      messageCount: this.messageCount,
      startedAt: this.startedAt,
    });

    server.send(
      json(
        sessionStartedEvent({
          language: config.language,
          model: config.model,
          sequence: this.nextSequence(),
          sessionId: config.sessionId,
        })
      )
    );

    const audioInput = new TransformStream<
      string | Uint8Array,
      string | Uint8Array
    >();
    this.audioInputWriter = audioInput.writable.getWriter();
    this.streamAbortController = new AbortController();
    const model = createRealtimeTranscriptionModel(this.env, {
      deepgram: config.deepgram,
      encoding: config.encoding,
      language: config.language,
      modelId: config.model,
      provider: config.provider,
      sampleRate: config.sampleRate,
      targetStreamingDelayMs: config.targetStreamingDelayMs,
      upstreamModel: config.upstreamModel,
    });
    this.streamResult = experimental_streamTranscribe({
      abortSignal: this.streamAbortController.signal,
      audio: audioInput.readable,
      inputAudioFormat: {
        ...(config.sampleRate ? { rate: config.sampleRate } : {}),
        type: inputAudioType(config.encoding),
      },
      model,
    });
    this.streamConsumptionPromise = this.consumeTranscriptionStream(
      server,
      config,
      this.streamResult
    );
    this.state.waitUntil(this.streamConsumptionPromise);

    server.addEventListener("message", (event) => {
      this.state.waitUntil(this.handleMessage(server, event, config));
    });

    server.addEventListener("close", () => {
      this.state.waitUntil(this.completeDisconnectedSession(server, config));
    });

    return new Response(null, { status: 101, webSocket: client });
  }

  private handleMessage(
    socket: WebSocket,
    event: MessageEvent,
    config: RealtimeSessionConfig
  ): Promise<void> {
    this.messageCount += 1;

    if (typeof event.data === "string") {
      return this.handleTextMessage(socket, event.data, config);
    }

    return this.handleAudioMessage(socket, event.data, config);
  }

  private async handleAudioMessage(
    socket: WebSocket,
    data: unknown,
    config: RealtimeSessionConfig
  ): Promise<void> {
    const audio = await audioBytes(data);
    const size = audio.byteLength;
    this.audioBytes += size;
    const writer = this.audioInputWriter;
    if (!writer) {
      throw new Error("realtime audio input is closed");
    }
    await writer.write(audio);
    socket.send(
      json({
        audio_bytes: this.audioBytes,
        chunk_bytes: size,
        message_count: this.messageCount,
        session_id: config.sessionId,
        type: "audio.received",
      })
    );
  }

  private async handleTextMessage(
    socket: WebSocket,
    data: string,
    config: RealtimeSessionConfig
  ): Promise<void> {
    let message: unknown;
    try {
      message = JSON.parse(data);
    } catch {
      socket.send(
        json({
          message_count: this.messageCount,
          session_id: config.sessionId,
          text: data,
          type: "text.received",
        })
      );
      return;
    }

    if (
      typeof message === "object" &&
      message !== null &&
      "type" in message &&
      message.type === "close"
    ) {
      await this.finishAudioInput();
      await this.streamConsumptionPromise;
      closeSocket(socket, 1000, "client requested close");
      return;
    }

    if (
      typeof message === "object" &&
      message !== null &&
      "type" in message &&
      message.type === "ping"
    ) {
      socket.send(
        json({
          message_count: this.messageCount,
          session_id: config.sessionId,
          type: "pong",
        })
      );
      return;
    }

    socket.send(
      json({
        message,
        message_count: this.messageCount,
        session_id: config.sessionId,
        type: "event.received",
      })
    );
  }

  private async consumeTranscriptionStream(
    socket: WebSocket,
    config: RealtimeSessionConfig,
    result: StreamTranscriptionResult
  ): Promise<void> {
    try {
      for await (const part of result.fullStream) {
        this.handleTranscriptionStreamPart(socket, config, part);
      }
      await result.text;
      await this.deliverTerminalSession(socket, config, "succeeded");
      closeSocket(socket, 1000, "realtime session completed");
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.streamError = message;
      await this.deliverTerminalSession(socket, config, "failed", message);
      closeSocket(socket, 1011, "realtime session failed");
    }
  }

  private handleTranscriptionStreamPart(
    socket: WebSocket,
    config: RealtimeSessionConfig,
    part: TranscriptionStreamPart
  ): void {
    if (part.type === "error") {
      throw part.error;
    }
    const event = realtimeTranscriptEventFromStreamPart(part);
    if (!event) {
      return;
    }
    this.transcriptEvents.push(event);
    const protocolEvent = transcriptProtocolEvent(
      config.sessionId,
      this.nextSequence(),
      event
    );
    if (protocolEvent) {
      safeSend(socket, json(protocolEvent));
    }
  }

  private async finishAudioInput(): Promise<void> {
    const writer = this.audioInputWriter;
    this.audioInputWriter = null;
    if (!writer) {
      return;
    }
    try {
      await writer.close();
    } catch {
      // The stream already failed or was aborted.
    } finally {
      writer.releaseLock();
    }
  }

  private async completeDisconnectedSession(
    socket: WebSocket,
    config: RealtimeSessionConfig
  ): Promise<void> {
    await this.state.storage.put("session", {
      audioBytes: this.audioBytes,
      config,
      endedAt: new Date().toISOString(),
      messageCount: this.messageCount,
    });
    await this.finishAudioInput();
    await this.streamConsumptionPromise;
    if (!this.terminalEventPromise) {
      await this.deliverTerminalSession(
        socket,
        config,
        this.streamError ? "failed" : "succeeded",
        this.streamError ?? undefined
      );
    }
    this.streamAbortController?.abort(
      new Error("TimberVox realtime client disconnected")
    );
    this.streamAbortController = null;
    this.streamResult = null;
  }

  private nextSequence(): number {
    this.eventSequence += 1;
    return this.eventSequence;
  }

  private async deliverTerminalSession(
    socket: WebSocket,
    config: RealtimeSessionConfig,
    status: "failed" | "succeeded",
    error?: string
  ): Promise<RealtimeSessionTerminalEvent> {
    if (!this.terminalEventPromise) {
      this.terminalEventPromise = this.createTerminalSessionEvent(
        config,
        status,
        error
      ).then((event) => {
        safeSend(socket, json(event));
        return event;
      });
    }
    return await this.terminalEventPromise;
  }

  private async createTerminalSessionEvent(
    config: RealtimeSessionConfig,
    status: "failed" | "succeeded",
    error?: string
  ): Promise<RealtimeSessionTerminalEvent> {
    const endedAt = new Date().toISOString();
    const startedAt = this.startedAt ?? endedAt;
    let persisted: RealtimePersistResult;
    try {
      persisted = await persistRealtimeResult(this.env, config, {
        audioBytes: this.audioBytes,
        endedAt,
        error,
        events: this.transcriptEvents,
        messageCount: this.messageCount,
        startedAt,
        status,
      });
    } catch (persistError) {
      console.error(
        JSON.stringify({
          error:
            persistError instanceof Error
              ? persistError.message
              : String(persistError),
          event: "realtime.persist_failed",
          session_id: config.sessionId,
        })
      );
      return terminalSessionEvent(
        {
          audioBytes: this.audioBytes,
          endedAt,
          error: `could not persist realtime result: ${
            persistError instanceof Error
              ? persistError.message
              : String(persistError)
          }`,
          errorCode: "session_error",
          language: config.language,
          messageCount: this.messageCount,
          model: config.model,
          provider: config.provider,
          sampleRate: config.sampleRate,
          sessionId: config.sessionId,
          startedAt,
          status: "failed",
          transcript: finalRealtimeTranscript(
            config.provider,
            this.transcriptEvents
          ),
        },
        this.nextSequence()
      );
    }
    return terminalSessionEvent(
      {
        audioBytes: this.audioBytes,
        endedAt,
        error,
        language: config.language,
        messageCount: this.messageCount,
        model: config.model,
        provider: config.provider,
        sampleRate: config.sampleRate,
        sessionId: config.sessionId,
        startedAt,
        status,
        transcript: persisted.transcript,
      },
      this.nextSequence()
    );
  }
}

const audioBytes = async (data: unknown): Promise<Uint8Array> => {
  if (data instanceof ArrayBuffer) {
    return new Uint8Array(data);
  }
  if (data instanceof Blob) {
    return new Uint8Array(await data.arrayBuffer());
  }
  if (ArrayBuffer.isView(data)) {
    return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
  }
  throw new Error("unsupported audio message payload");
};

const safeSend = (socket: WebSocket, data: string): boolean => {
  try {
    socket.send(data);
    return true;
  } catch {
    return false;
  }
};

const inputAudioType = (encoding: string | null): string => {
  if (encoding === "mulaw" || encoding === "pcm_mulaw") {
    return "audio/pcmu";
  }
  if (encoding === "alaw" || encoding === "pcm_alaw") {
    return "audio/pcma";
  }
  return "audio/pcm";
};
