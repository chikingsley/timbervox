import { z } from "zod";

import type { DeepgramRealtimeOptions } from "../ai/deepgram/realtime/client";
import type { RealtimeAsrProviderId } from "../ai/models/types";
import {
  createRealtimeProviderBridge,
  type RealtimeProviderBridge,
} from "../ai/realtime/bridge";
import {
  finalRealtimeTranscript,
  type RealtimeTranscriptEvent,
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

const PROVIDER_FLUSH_TIMEOUT_MS = 3000;

export class RealtimeSession {
  private audioBytes = 0;
  private readonly env: Env;
  private eventSequence = 0;
  private messageCount = 0;
  private providerBridge: RealtimeProviderBridge | null = null;
  private providerSocket: WebSocket | null = null;
  private providerSocketPromise: Promise<WebSocket> | null = null;
  private providerClosed = false;
  private providerClosedWaiters: Array<() => void> = [];
  private providerError: string | null = null;
  private providerMessageQueue: Promise<void> = Promise.resolve();
  private readonly state: DurableObjectState;
  private startedAt: string | null = null;
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

    this.providerSocketPromise = this.connectProvider(server, config);
    this.state.waitUntil(this.providerSocketPromise.catch(() => undefined));

    server.addEventListener("message", (event) => {
      this.state.waitUntil(this.handleMessage(server, event, config));
    });

    server.addEventListener("close", () => {
      this.closeProvider();
      this.state.waitUntil(
        Promise.all([
          this.state.storage.put("session", {
            audioBytes: this.audioBytes,
            config,
            endedAt: new Date().toISOString(),
            messageCount: this.messageCount,
          }),
          this.providerMessageQueue.then(() =>
            this.deliverTerminalSession(server, config, "succeeded")
          ),
        ])
      );
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
    await this.withProviderSocket((providerSocket) => {
      this.requiredProviderBridge().sendAudio(providerSocket, audio);
    });
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
      try {
        await this.withProviderSocket((providerSocket) => {
          this.requiredProviderBridge().closeStream(providerSocket);
        });
        await this.waitForProviderClose(PROVIDER_FLUSH_TIMEOUT_MS);
      } catch {
        // No provider socket to flush; end the session directly.
      }
      await this.providerMessageQueue;
      await this.deliverTerminalSession(socket, config, "succeeded");
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

    let forwarded = false;
    await this.withProviderSocket((providerSocket) => {
      forwarded = this.requiredProviderBridge().forwardClientMessage(
        providerSocket,
        message
      );
    });
    if (forwarded) {
      socket.send(
        json({
          message_count: this.messageCount,
          provider: config.provider,
          session_id: config.sessionId,
          type: "event.forwarded",
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

  private async connectProvider(
    socket: WebSocket,
    config: RealtimeSessionConfig
  ): Promise<WebSocket> {
    try {
      const bridge = createRealtimeProviderBridge(this.env, config);
      this.providerBridge = bridge;
      const providerSocket = await bridge.connect();
      this.providerSocket = providerSocket;
      this.attachProviderSocket(socket, providerSocket, config, bridge);
      return providerSocket;
    } catch (error) {
      await this.deliverTerminalSession(
        socket,
        config,
        "failed",
        error instanceof Error ? error.message : String(error)
      );
      closeSocket(socket, 1011, "provider connection failed");
      throw error;
    }
  }

  private attachProviderSocket(
    clientSocket: WebSocket,
    providerSocket: WebSocket,
    config: RealtimeSessionConfig,
    bridge: RealtimeProviderBridge
  ): void {
    providerSocket.addEventListener("message", (event) => {
      this.providerMessageQueue = this.providerMessageQueue
        .then(() =>
          this.forwardProviderMessage(clientSocket, event, config, bridge)
        )
        .catch(async (error: unknown) => {
          const message =
            error instanceof Error ? error.message : String(error);
          this.providerError = message;
          await this.deliverTerminalSession(
            clientSocket,
            config,
            "failed",
            message
          );
          closeSocket(clientSocket, 1011, "realtime session failed");
        });
      this.state.waitUntil(this.providerMessageQueue);
    });
    providerSocket.addEventListener("close", () => {
      this.resolveProviderClosed();
      this.state.waitUntil(
        this.providerMessageQueue
          .then(() =>
            this.deliverTerminalSession(
              clientSocket,
              config,
              this.providerError ? "failed" : "succeeded",
              this.providerError ?? undefined
            )
          )
          .then(() =>
            closeSocket(clientSocket, 1000, "realtime session completed")
          )
      );
    });
    providerSocket.addEventListener("error", () => {
      this.resolveProviderClosed();
      this.providerError = "provider error";
      this.state.waitUntil(
        this.providerMessageQueue
          .then(() =>
            this.deliverTerminalSession(
              clientSocket,
              config,
              "failed",
              "provider error"
            )
          )
          .then(() => closeSocket(clientSocket, 1011, "provider error"))
      );
    });
  }

  private resolveProviderClosed(): void {
    this.providerClosed = true;
    const waiters = this.providerClosedWaiters;
    this.providerClosedWaiters = [];
    for (const waiter of waiters) {
      waiter();
    }
  }

  private hasProviderClosed(): boolean {
    return this.providerClosed;
  }

  private waitForProviderClose(timeoutMs: number): Promise<void> {
    if (this.hasProviderClosed()) {
      return Promise.resolve();
    }
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        resolve();
      }, timeoutMs);
      this.providerClosedWaiters.push(() => {
        clearTimeout(timer);
        resolve();
      });
    });
  }

  private async forwardProviderMessage(
    clientSocket: WebSocket,
    event: MessageEvent,
    config: RealtimeSessionConfig,
    bridge: RealtimeProviderBridge
  ): Promise<void> {
    const data = await messageDataToString(event.data);
    const parsed = bridge.parseMessage(data);
    if (parsed.shouldPersistProviderEvent && parsed.providerEvent) {
      await this.state.storage.put("transcription", parsed.providerEvent);
    }
    if (parsed.transcriptEvent) {
      this.transcriptEvents.push(parsed.transcriptEvent);
      const protocolEvent =
        parsed.transcriptEvent.delivery === "complete"
          ? null
          : transcriptProtocolEvent(
              config.sessionId,
              this.nextSequence(),
              parsed.transcriptEvent
            );
      if (protocolEvent) {
        safeSend(clientSocket, json(protocolEvent));
      }
      if (parsed.transcriptEvent.delivery === "complete") {
        await this.deliverTerminalSession(clientSocket, config, "succeeded");
        closeSocket(clientSocket, 1000, "realtime session completed");
      }
    }
    if (parsed.providerError) {
      this.providerError = parsed.providerError;
      await this.deliverTerminalSession(
        clientSocket,
        config,
        "failed",
        parsed.providerError
      );
      closeSocket(clientSocket, 1011, "provider error");
    }
  }

  private async withProviderSocket(
    action: (providerSocket: WebSocket) => void
  ): Promise<void> {
    const providerSocket = await this.providerSocketPromise;
    if (!providerSocket) {
      throw new Error("provider socket is not connected");
    }
    action(providerSocket);
  }

  private requiredProviderBridge(): RealtimeProviderBridge {
    if (!this.providerBridge) {
      throw new Error("provider bridge is not connected");
    }
    return this.providerBridge;
  }

  private currentProviderSocket(): WebSocket | null {
    return this.providerSocket;
  }

  private closeProvider(): void {
    const bridge = this.providerBridge;
    const providerSocket = this.currentProviderSocket();
    this.providerSocket = null;
    this.providerBridge = null;
    if (providerSocket && bridge) {
      bridge.close(providerSocket);
      closeSocket(providerSocket, 1000, "client disconnected");
    }
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

const messageDataToString = async (data: unknown): Promise<string> => {
  if (typeof data === "string") {
    return data;
  }
  if (data instanceof ArrayBuffer) {
    return new TextDecoder().decode(data);
  }
  if (data instanceof Blob) {
    return await data.text();
  }
  if (ArrayBuffer.isView(data)) {
    return new TextDecoder().decode(
      new Uint8Array(data.buffer, data.byteOffset, data.byteLength)
    );
  }
  return JSON.stringify(data);
};
