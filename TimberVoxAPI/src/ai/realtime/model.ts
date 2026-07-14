import {
  type Experimental_TranscriptionModelV4StreamOptions,
  type Experimental_TranscriptionModelV4StreamPart,
  type Experimental_TranscriptionModelV4StreamResult,
  type JSONObject,
  type TranscriptionModelV4,
  type TranscriptionModelV4CallOptions,
  type TranscriptionModelV4Result,
  UnsupportedFunctionalityError,
} from "@ai-sdk/provider";

import type { Env } from "../../bindings";
import {
  createRealtimeProviderConnection,
  type RealtimeProviderConnection,
  type RealtimeProviderConnectionConfig,
} from "./connection";
import {
  finalRealtimeTranscript,
  type RealtimeTranscriptEvent,
} from "./normalize";

export interface RealtimeTranscriptionModelConfig
  extends RealtimeProviderConnectionConfig {
  language: string | null;
  modelId: string;
}

const STREAM_FLUSH_TIMEOUT_MS = 4000;

export const createRealtimeTranscriptionModel = (
  env: Env,
  config: RealtimeTranscriptionModelConfig
): TranscriptionModelV4 => new RealtimeTranscriptionModel(env, config);

class RealtimeTranscriptionModel implements TranscriptionModelV4 {
  readonly modelId: string;
  readonly provider: string;
  readonly specificationVersion = "v4" as const;
  private readonly config: RealtimeTranscriptionModelConfig;
  private readonly env: Env;

  constructor(env: Env, config: RealtimeTranscriptionModelConfig) {
    this.config = config;
    this.env = env;
    this.modelId = config.modelId;
    this.provider = config.provider;
  }

  doGenerate(
    _options: TranscriptionModelV4CallOptions
  ): PromiseLike<TranscriptionModelV4Result> {
    throw new UnsupportedFunctionalityError({
      functionality: `batch transcription with realtime-only model ${this.modelId}`,
    });
  }

  doStream(
    options: Experimental_TranscriptionModelV4StreamOptions
  ): PromiseLike<Experimental_TranscriptionModelV4StreamResult> {
    const config = configWithInputFormat(this.config, options);
    const connection = createRealtimeProviderConnection(this.env, config);
    let runner: RealtimeModelStream | null = null;
    const stream =
      new ReadableStream<Experimental_TranscriptionModelV4StreamPart>({
        cancel: (reason) => runner?.cancel(reason),
        start: async (controller) => {
          runner = new RealtimeModelStream(
            connection,
            config,
            options,
            controller
          );
          await runner.start();
        },
      });
    return Promise.resolve({
      response: {
        modelId: this.modelId,
        timestamp: new Date(),
      },
      stream,
    });
  }
}

type StreamStatus = "cancelled" | "failed" | "finished" | "running";

class RealtimeModelStream {
  private audioBytes = 0;
  private audioReader: ReadableStreamDefaultReader<string | Uint8Array> | null =
    null;
  private readonly config: RealtimeTranscriptionModelConfig;
  private readonly connection: RealtimeProviderConnection;
  private readonly controller: ReadableStreamDefaultController<Experimental_TranscriptionModelV4StreamPart>;
  private inputEnded = false;
  private messageQueue: Promise<void> = Promise.resolve();
  private readonly options: Experimental_TranscriptionModelV4StreamOptions;
  private providerSocket: WebSocket | null = null;
  private status: StreamStatus = "running";
  private readonly terminal: Promise<void>;
  private terminalResolve: () => void = () => undefined;
  private readonly transcriptEvents: RealtimeTranscriptEvent[] = [];

  constructor(
    connection: RealtimeProviderConnection,
    config: RealtimeTranscriptionModelConfig,
    options: Experimental_TranscriptionModelV4StreamOptions,
    controller: ReadableStreamDefaultController<Experimental_TranscriptionModelV4StreamPart>
  ) {
    this.connection = connection;
    this.config = config;
    this.options = options;
    this.controller = controller;
    this.terminal = new Promise((resolve) => {
      this.terminalResolve = resolve;
    });
  }

  async start(): Promise<void> {
    this.controller.enqueue({ type: "stream-start", warnings: [] });
    try {
      this.providerSocket = await this.connection.connect();
      this.attachProviderSocket(this.providerSocket);
      this.controller.enqueue({
        modelId: this.config.modelId,
        timestamp: new Date(),
        type: "response-metadata",
      });
      this.attachAbortSignal();
      await this.forwardAudio();
      this.inputEnded = true;
      if (this.status === "running" && this.providerSocket) {
        this.connection.finish(this.providerSocket);
      }
      await this.waitForTerminal();
      if (this.status === "running") {
        this.succeed();
      }
    } catch (error) {
      this.fail(error);
    } finally {
      this.detachAbortSignal();
      this.audioReader?.releaseLock();
      this.audioReader = null;
    }
  }

  async cancel(reason: unknown): Promise<void> {
    if (this.status !== "running") {
      return;
    }
    this.status = "cancelled";
    await this.audioReader?.cancel(reason).catch(() => undefined);
    this.closeProvider();
    this.terminalResolve();
  }

  private readonly abort = (): void => {
    const reason =
      this.options.abortSignal?.reason ??
      new Error("realtime transcription aborted");
    this.cancel(reason).catch(() => undefined);
  };

  private attachAbortSignal(): void {
    if (!this.options.abortSignal) {
      return;
    }
    if (this.options.abortSignal.aborted) {
      this.abort();
      return;
    }
    this.options.abortSignal.addEventListener("abort", this.abort, {
      once: true,
    });
  }

  private detachAbortSignal(): void {
    this.options.abortSignal?.removeEventListener("abort", this.abort);
  }

  private attachProviderSocket(socket: WebSocket): void {
    socket.addEventListener("message", (event) => {
      this.messageQueue = this.messageQueue
        .then(() => this.handleProviderMessage(event.data))
        .catch((error: unknown) => {
          this.fail(error);
        });
    });
    socket.addEventListener("close", () => {
      this.messageQueue = this.messageQueue
        .then(() => {
          this.handleProviderClose();
        })
        .catch((error: unknown) => {
          this.fail(error);
        });
    });
    socket.addEventListener("error", () => {
      this.fail(new Error(`${this.connection.provider} realtime socket error`));
    });
  }

  private handleProviderClose(): void {
    // biome-ignore lint/suspicious/noUnnecessaryConditions: the WebSocket callback observes this after the audio pump mutates it.
    if (this.inputEnded) {
      this.succeed();
      return;
    }
    this.fail(
      new Error(
        `${this.connection.provider} realtime socket closed before audio ended`
      )
    );
  }

  private async forwardAudio(): Promise<void> {
    this.audioReader = this.options.audio.getReader();
    while (this.status === "running") {
      // biome-ignore lint/performance/noAwaitInLoops: stream chunks must retain arrival order and backpressure.
      const { done, value } = await this.audioReader.read();
      if (done) {
        return;
      }
      const audio = decodeAudioChunk(value);
      this.audioBytes += audio.byteLength;
      const socket = this.providerSocket;
      if (!socket) {
        throw new Error("realtime provider socket is not connected");
      }
      this.connection.sendAudio(socket, audio);
    }
  }

  private async handleProviderMessage(data: unknown): Promise<void> {
    if (this.status !== "running") {
      return;
    }
    const raw = await messageDataToString(data);
    const parsed = this.connection.parseMessage(raw);
    if (this.options.includeRawChunks && parsed.providerEvent !== undefined) {
      this.controller.enqueue({
        rawValue: parsed.providerEvent,
        type: "raw",
      });
    }
    if (parsed.providerError) {
      this.fail(new Error(parsed.providerError));
      return;
    }
    if (!parsed.transcriptEvent) {
      return;
    }
    this.transcriptEvents.push(parsed.transcriptEvent);
    const part = transcriptStreamPart(
      this.transcriptEvents.length,
      parsed.transcriptEvent
    );
    if (part) {
      this.controller.enqueue(part);
    }
    if (parsed.transcriptEvent.delivery === "complete") {
      this.succeed();
      this.closeProvider();
    }
  }

  private waitForTerminal(): Promise<void> {
    if (this.status !== "running") {
      return Promise.resolve();
    }
    return new Promise((resolve) => {
      const timeout = setTimeout(resolve, STREAM_FLUSH_TIMEOUT_MS);
      this.terminal.then(() => {
        clearTimeout(timeout);
        resolve();
      });
    });
  }

  private succeed(): void {
    if (this.status !== "running") {
      return;
    }
    this.status = "finished";
    const text = finalRealtimeTranscript(
      this.config.provider,
      this.transcriptEvents
    );
    this.controller.enqueue({
      durationInSeconds: audioDurationSeconds(
        this.audioBytes,
        this.options.inputAudioFormat.type,
        this.config.sampleRate
      ),
      ...(this.config.language && this.config.language !== "multi"
        ? { language: this.config.language }
        : {}),
      segments: finalSegments(this.transcriptEvents),
      text,
      type: "finish",
    });
    this.controller.close();
    this.terminalResolve();
  }

  private fail(error: unknown): void {
    if (this.status !== "running") {
      return;
    }
    this.status = "failed";
    this.controller.enqueue({ error, type: "error" });
    this.controller.close();
    this.closeProvider();
    this.terminalResolve();
  }

  private closeProvider(): void {
    const socket = this.providerSocket;
    this.providerSocket = null;
    if (!socket) {
      return;
    }
    try {
      this.connection.close(socket);
    } catch {
      // The provider socket was already closing or closed.
    }
    try {
      socket.close(1000, "transcription stream ended");
    } catch {
      // The provider socket was already closing or closed.
    }
  }
}

const configWithInputFormat = (
  config: RealtimeTranscriptionModelConfig,
  options: Experimental_TranscriptionModelV4StreamOptions
): RealtimeTranscriptionModelConfig => {
  const sampleRate = config.sampleRate ?? options.inputAudioFormat.rate ?? null;
  const encoding =
    config.encoding ?? inputFormatEncoding(options.inputAudioFormat.type);
  return {
    ...config,
    deepgram: {
      ...config.deepgram,
      encoding: config.deepgram.encoding ?? encoding ?? undefined,
      sampleRate: config.deepgram.sampleRate ?? sampleRate ?? undefined,
    },
    encoding,
    sampleRate,
  };
};

const inputFormatEncoding = (type: string): string | null => {
  const normalized = type.toLowerCase();
  if (normalized === "audio/pcm" || normalized === "audio/l16") {
    return "linear16";
  }
  if (normalized === "audio/pcmu") {
    return "mulaw";
  }
  if (normalized === "audio/pcma") {
    return "alaw";
  }
  return null;
};

const transcriptStreamPart = (
  sequence: number,
  event: RealtimeTranscriptEvent
): Experimental_TranscriptionModelV4StreamPart | null => {
  if (event.delivery === "complete") {
    return null;
  }
  const metadata = transcriptProviderMetadata(event);
  const [segment] = event.segments;
  if (event.delivery === "delta") {
    return {
      delta: event.text,
      id: String(sequence),
      providerMetadata: metadata,
      type: "transcript-delta",
    };
  }
  if (event.delivery === "interim") {
    return {
      ...(segment
        ? {
            durationInSeconds: segment.endSeconds - segment.startSeconds,
            startSecond: segment.startSeconds,
          }
        : {}),
      id: String(sequence),
      providerMetadata: metadata,
      text: event.text,
      type: "transcript-partial",
    };
  }
  return {
    ...(segment
      ? {
          endSecond: segment.endSeconds,
          startSecond: segment.startSeconds,
        }
      : {}),
    id: String(sequence),
    providerMetadata: metadata,
    text: event.text,
    type: "transcript-final",
  };
};

const transcriptProviderMetadata = (
  event: RealtimeTranscriptEvent
): Record<string, JSONObject> => ({
  timbervox: {
    delivery: event.delivery,
    isFinal: event.isFinal,
    segments: event.segments,
    speakerTurns: event.speakerTurns,
    ...(event.speechFinal === undefined
      ? {}
      : { speechFinal: event.speechFinal }),
    words: event.words,
  },
});

const finalSegments = (
  events: readonly RealtimeTranscriptEvent[]
): Array<{ endSecond: number; startSecond: number; text: string }> =>
  events
    .filter((event) => event.delivery === "committed")
    .flatMap((event) =>
      event.segments.map((segment) => ({
        endSecond: segment.endSeconds,
        startSecond: segment.startSeconds,
        text: segment.text,
      }))
    );

const decodeAudioChunk = (chunk: string | Uint8Array): Uint8Array => {
  if (chunk instanceof Uint8Array) {
    return chunk;
  }
  const binary = atob(chunk);
  return Uint8Array.from(binary, (character) => character.codePointAt(0) ?? 0);
};

const audioDurationSeconds = (
  audioBytes: number,
  type: string,
  sampleRate: number | null
): number | undefined => {
  if (!sampleRate || audioBytes <= 0) {
    return;
  }
  const normalized = type.toLowerCase();
  const bytesPerSample =
    normalized === "audio/pcmu" || normalized === "audio/pcma" ? 1 : 2;
  return audioBytes / bytesPerSample / sampleRate;
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
