import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

import { z } from "zod";

const defaultBaseUrl = "https://timbervox.peacockery.studio";
const defaultRuns = 3;
const defaultWarmups = 1;
const maxOutputTokens = 1024;
const requestTimeoutMs = 120_000;
const benchmarkProfile = "timbervox-text-stream-v2";
const trailingSlashPattern = /\/$/;

const transcriptSections = [
  "okay so first the design review is moving from tuesday morning to thursday afternoon because the accessibility audit needs another day and maya will send the revised invitation before lunch the mobile team should keep the current branch open until the review is finished but no one should merge the experimental navigation changes yet",
  "second the customer interview notes need to distinguish requests from confirmed commitments three people asked for offline access two people mentioned faster search and one person described a sync problem after changing phones those observations belong in the research summary but they are not promises for the next release",
  "for the launch checklist jordan owns the app store description priya owns the screenshots and sam owns the support article the privacy answers are already drafted but legal still needs to confirm the data retention paragraph if approval arrives by friday the team can submit monday otherwise submission moves to the following wednesday",
  "the recording workflow should start immediately show a clear listening state and keep the selected mode visible while audio is captured when the user stops speaking the final transcript should replace the temporary text without moving the main action button or hiding the keyboard controls",
  "during testing we found that short messages usually finish quickly but longer notes can expose provider delays so the status copy should say transcribing while speech recognition is completing and processing only while the language model is transforming the transcript those are separate stages even though they belong to one dictation workflow",
  "the settings page needs plain language labels for microphone access keyboard installation full access and notification permission a green status means the operating system reports that access is available and a neutral status means the app cannot confirm it yet neither state should claim that a live recording path has been tested",
  "for storage keep the transcript by default and let the user choose when audio is deleted the choices discussed were immediately after processing after one day after one week after one month or never storage usage should show the amount on this device and clearing recordings must require confirmation",
  "the history entry should use a short generated title when one exists otherwise it should begin with the transcript text the detail view can switch between raw segmented and processed text but the list itself only needs the date duration word count and mode icon so that scanning remains fast",
  "finally the benchmark result must record the exact provider route model identifier prompt profile run count and timestamp because latest aliases can change without warning report the configured route exactly report the median rather than the fastest sample and keep failed requests visible instead of silently dropping them",
  "one more correction the meeting is not at three thirty it is at four fifteen and the room is cedar not cypress please preserve both corrections exactly send the final note to alex chen and spell the project name timbervox with a capital t and a capital v",
] as const;

const systemPrompt =
  "You are a dictation text formatter. Return only the cleaned transcript. Preserve every factual detail and sentence in the original order. Correct capitalization and punctuation, remove verbal filler, and apply explicit self-corrections. Do not summarize, add headings, or invent information.";

const ModelCatalog = z.object({
  models: z.array(
    z.object({
      id: z.string(),
      kind: z.enum(["language", "transcription"]),
      provider: z.string(),
      upstream_model: z.string(),
    })
  ),
});

const StreamStartedEvent = z.object({
  model: z.string(),
  protocol_version: z.literal(1),
  provider: z.string(),
  sequence: z.number().int().nonnegative(),
  type: z.literal("stream.started"),
  upstream_model: z.string(),
});

const TextDeltaEvent = z.object({
  delta: z.string(),
  protocol_version: z.literal(1),
  sequence: z.number().int().nonnegative(),
  type: z.literal("text.delta"),
});

const StreamCompletedEvent = z.object({
  finish_reason: z.string(),
  model: z.string(),
  performance: z.object({
    effective_output_tokens_per_second: z.number(),
    output_tokens_per_second: z.number().optional(),
    response_time_ms: z.number(),
    step_time_ms: z.number(),
    time_to_first_output_ms: z.number().optional(),
  }),
  protocol_version: z.literal(1),
  provider: z.string(),
  provider_latency_ms: z.number(),
  response_model_id: z.string(),
  sequence: z.number().int().nonnegative(),
  type: z.literal("stream.completed"),
  upstream_model: z.string(),
  usage: z.object({
    input_tokens: z.number().optional(),
    output_tokens: z.number().optional(),
    reasoning_tokens: z.number().optional(),
    text_tokens: z.number().optional(),
    total_tokens: z.number().optional(),
  }),
  warnings: z.array(z.unknown()).optional(),
});

const StreamFailedEvent = z.object({
  error: z.object({
    category: z
      .enum([
        "authentication",
        "empty_output",
        "invalid_request",
        "network",
        "rate_limited",
        "timeout",
        "unavailable",
        "unknown",
      ])
      .optional(),
    code: z.enum(["empty_output", "provider_error", "stream_error"]),
    message: z.string(),
    provider_code: z.string().optional(),
    retry_after_ms: z.number().optional(),
    retryable: z.boolean().optional(),
    status_code: z.number().int().optional(),
  }),
  model: z.string(),
  protocol_version: z.literal(1),
  provider: z.string(),
  provider_latency_ms: z.number(),
  sequence: z.number().int().nonnegative(),
  type: z.literal("stream.failed"),
  upstream_model: z.string(),
});

const TextStreamEvent = z.discriminatedUnion("type", [
  StreamStartedEvent,
  TextDeltaEvent,
  StreamCompletedEvent,
  StreamFailedEvent,
]);

type TextStreamEvent = z.infer<typeof TextStreamEvent>;
type StreamCompletedEvent = z.infer<typeof StreamCompletedEvent>;

interface Arguments {
  baseUrl: string;
  models: string[] | undefined;
  outputPath: string | undefined;
  runs: number;
  warmups: number;
}

interface CatalogModel {
  id: string;
  provider: string;
  upstreamModel: string;
}

interface BenchmarkSample {
  cfRay: string | null;
  clientEffectiveTextTokensPerSecond: number;
  clientOutputTextTokensPerSecond: number | undefined;
  clientResponseTimeMs: number;
  finishReason: string;
  inputTokens: number | undefined;
  model: string;
  outputCharacters: number;
  outputTokens: number | undefined;
  provider: string;
  providerEffectiveOutputTokensPerSecond: number;
  providerLatencyMs: number;
  providerOutputTokensPerSecond: number | undefined;
  reasoningTokens: number | undefined;
  responseModelId: string;
  run: number;
  textTokens: number | undefined;
  timeToFirstTextMs: number | undefined;
  totalTokens: number | undefined;
  upstreamModel: string;
  warmup: boolean;
}

interface BenchmarkFailure {
  category?: z.infer<typeof StreamFailedEvent>["error"]["category"];
  message: string;
  model: string;
  providerCode?: string;
  retryAfterMs?: number;
  retryable?: boolean;
  run: number;
  statusCode?: number;
  warmup: boolean;
}

class BenchmarkStreamFailure extends Error {
  readonly failure: Omit<BenchmarkFailure, "model" | "run" | "warmup">;

  constructor(error: z.infer<typeof StreamFailedEvent>["error"]) {
    super(`${error.code}: ${error.message}`);
    this.name = "BenchmarkStreamFailure";
    this.failure = {
      category: error.category,
      message: error.message,
      providerCode: error.provider_code,
      retryAfterMs: error.retry_after_ms,
      retryable: error.retryable,
      statusCode: error.status_code,
    };
  }
}

interface ModelSummary {
  clientEffectiveTextTokensPerSecondMedian: number;
  clientOutputTextTokensPerSecondMedian: number | undefined;
  clientResponseTimeMsMedian: number;
  model: string;
  provider: string;
  providerEffectiveOutputTokensPerSecondMedian: number;
  providerOutputTokensPerSecondMedian: number | undefined;
  responseModelIds: string[];
  samples: number;
  timeToFirstTextMsMedian: number | undefined;
  upstreamModel: string;
}

const usage = `Usage: pnpm benchmark:text [options]

Options:
  --base-url <url> TimberVox API origin (default: ${defaultBaseUrl}).
  --models <ids>   Comma-separated TimberVox model route IDs.
  --runs <count>   Measured runs per model (default: ${defaultRuns}).
  --warmups <n>    Warm-up runs per model (default: ${defaultWarmups}).
  --output <path>  Write the complete JSON report to this path.
  --help           Show this help.
`;

const parsePositiveInteger = (value: string, name: string): number => {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    throw new Error(`${name} must be a nonnegative integer`);
  }
  return parsed;
};

const requiredValue = (arguments_: string[], index: number): string => {
  const value = arguments_[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`missing value for ${arguments_[index]}`);
  }
  return value;
};

const parseArguments = (arguments_: string[]): Arguments => {
  let baseUrl = defaultBaseUrl;
  let models: string[] | undefined;
  let outputPath: string | undefined;
  let runs = defaultRuns;
  let warmups = defaultWarmups;

  for (let index = 0; index < arguments_.length; index += 1) {
    const argument = arguments_[index];
    if (argument === "--help") {
      process.stdout.write(usage);
      process.exit(0);
    }
    if (argument === "--base-url") {
      baseUrl = requiredValue(arguments_, index).replace(
        trailingSlashPattern,
        ""
      );
      index += 1;
      continue;
    }
    if (argument === "--models") {
      models = requiredValue(arguments_, index)
        .split(",")
        .map((model) => model.trim())
        .filter(Boolean);
      index += 1;
      continue;
    }
    if (argument === "--output") {
      outputPath = requiredValue(arguments_, index);
      index += 1;
      continue;
    }
    if (argument === "--runs") {
      runs = parsePositiveInteger(requiredValue(arguments_, index), "runs");
      index += 1;
      continue;
    }
    if (argument === "--warmups") {
      warmups = parsePositiveInteger(
        requiredValue(arguments_, index),
        "warmups"
      );
      index += 1;
      continue;
    }
    throw new Error(`unknown argument: ${argument}`);
  }

  if (runs < 1) {
    throw new Error("runs must be at least 1");
  }
  if (models?.length === 0) {
    throw new Error("models must include at least one route ID");
  }
  return { baseUrl, models, outputPath, runs, warmups };
};

const configuredApiKey = (): string => {
  const value = process.env.TIMBERVOX_API_KEY?.trim();
  if (!value) {
    throw new Error("TIMBERVOX_API_KEY is required");
  }
  return value;
};

const fetchCatalog = async (baseUrl: string): Promise<CatalogModel[]> => {
  const response = await fetch(`${baseUrl}/v1/models`);
  if (!response.ok) {
    throw new Error(`model catalog returned HTTP ${response.status}`);
  }
  return ModelCatalog.parse(await response.json()).models.flatMap((model) =>
    model.kind === "language"
      ? [
          {
            id: model.id,
            provider: model.provider,
            upstreamModel: model.upstream_model,
          },
        ]
      : []
  );
};

const selectedModels = (
  catalog: CatalogModel[],
  requested: string[] | undefined
): CatalogModel[] => {
  if (!requested) {
    return catalog;
  }
  const byId = new Map(catalog.map((model) => [model.id, model]));
  return requested.map((modelId) => {
    const model = byId.get(modelId);
    if (!model) {
      throw new Error(`unsupported or unconfigured language model: ${modelId}`);
    }
    return model;
  });
};

const rotatedTranscript = (run: number): string => {
  const offset = run % transcriptSections.length;
  const rotated = [
    ...transcriptSections.slice(offset),
    ...transcriptSections.slice(0, offset),
  ];
  return `${rotated.join("\n\n")}\n\nbenchmark run marker ${run}`;
};

const median = (values: number[]): number | undefined => {
  if (values.length === 0) {
    return;
  }
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  const upper = sorted[middle];
  if (sorted.length % 2 === 1) {
    return upper;
  }
  const lower = sorted[middle - 1];
  return (lower + upper) / 2;
};

const rounded = (value: number): number => Math.round(value * 10) / 10;

const parseSseFrame = (frame: string): TextStreamEvent | undefined => {
  const lines = frame.split("\n");
  const eventName = lines
    .find((line) => line.startsWith("event:"))
    ?.slice("event:".length)
    .trim();
  const data = lines
    .filter((line) => line.startsWith("data:"))
    .map((line) => line.slice("data:".length).trimStart())
    .join("\n");
  if (!data) {
    return;
  }
  const event = TextStreamEvent.parse(JSON.parse(data));
  if (eventName && eventName !== event.type) {
    throw new Error(
      `SSE event name ${eventName} did not match payload type ${event.type}`
    );
  }
  return event;
};

const consumeSse = async (
  body: ReadableStream<Uint8Array>,
  onEvent: (event: TextStreamEvent) => void
): Promise<void> => {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  const dispatchCompleteFrames = (): void => {
    let boundary = buffer.indexOf("\n\n");
    while (boundary >= 0) {
      const frame = buffer.slice(0, boundary);
      buffer = buffer.slice(boundary + 2);
      const event = parseSseFrame(frame);
      if (event) {
        onEvent(event);
      }
      boundary = buffer.indexOf("\n\n");
    }
  };
  const readNext = async (): Promise<void> => {
    const { done, value } = await reader.read();
    buffer += decoder.decode(value, { stream: !done }).replaceAll("\r\n", "\n");
    dispatchCompleteFrames();
    if (done) {
      const event = parseSseFrame(buffer);
      if (event) {
        onEvent(event);
      }
      return;
    }
    await readNext();
  };
  await readNext();
};

const requireCompletedEvent = (
  event: StreamCompletedEvent | undefined
): StreamCompletedEvent => {
  if (!event) {
    throw new Error("stream ended without stream.completed");
  }
  return event;
};

const benchmarkSample = async (input: {
  apiKey: string;
  baseUrl: string;
  model: CatalogModel;
  run: number;
  warmup: boolean;
}): Promise<BenchmarkSample> => {
  const requestStarted = performance.now();
  let completedAt: number | undefined;
  let completedEvent: StreamCompletedEvent | undefined;
  let firstTextAt: number | undefined;
  let outputText = "";
  let previousSequence = -1;

  const response = await fetch(`${input.baseUrl}/v1/text/stream`, {
    body: JSON.stringify({
      maxOutputTokens,
      messages: [
        { content: systemPrompt, role: "system" },
        { content: rotatedTranscript(input.run), role: "user" },
      ],
      model: input.model.id,
      temperature: 0,
    }),
    headers: {
      Authorization: `Bearer ${input.apiKey}`,
      "content-type": "application/json",
    },
    method: "POST",
    signal: AbortSignal.timeout(requestTimeoutMs),
  });
  if (!response.ok) {
    throw new Error(
      `stream endpoint returned HTTP ${response.status}: ${await response.text()}`
    );
  }
  if (!response.body) {
    throw new Error("stream endpoint returned no response body");
  }

  await consumeSse(response.body, (event) => {
    if (event.sequence <= previousSequence) {
      throw new Error(`out-of-order SSE sequence ${event.sequence}`);
    }
    previousSequence = event.sequence;
    if (event.type === "text.delta") {
      firstTextAt ??= performance.now();
      outputText += event.delta;
      return;
    }
    if (event.type === "stream.failed") {
      throw new BenchmarkStreamFailure(event.error);
    }
    if (event.type === "stream.completed") {
      completedAt = performance.now();
      completedEvent = event;
    }
  });

  const completed = requireCompletedEvent(completedEvent);
  const finishedAt = completedAt ?? performance.now();
  const clientResponseTimeMs = finishedAt - requestStarted;
  if (!firstTextAt || outputText.length === 0) {
    throw new Error("stream completed without a text.delta event");
  }
  const visibleOutputTokens =
    completed.usage.text_tokens ?? completed.usage.output_tokens;
  if (visibleOutputTokens === undefined || visibleOutputTokens < 1) {
    throw new Error("stream completed without a positive output token count");
  }
  const outputWindowMs = Math.max(finishedAt - firstTextAt, 1);

  return {
    cfRay: response.headers.get("cf-ray"),
    clientEffectiveTextTokensPerSecond:
      visibleOutputTokens / (clientResponseTimeMs / 1000),
    clientOutputTextTokensPerSecond:
      visibleOutputTokens / (outputWindowMs / 1000),
    clientResponseTimeMs,
    finishReason: completed.finish_reason,
    inputTokens: completed.usage.input_tokens,
    model: input.model.id,
    outputCharacters: outputText.length,
    outputTokens: completed.usage.output_tokens,
    provider: completed.provider,
    providerEffectiveOutputTokensPerSecond:
      completed.performance.effective_output_tokens_per_second,
    providerLatencyMs: completed.provider_latency_ms,
    providerOutputTokensPerSecond:
      completed.performance.output_tokens_per_second,
    reasoningTokens: completed.usage.reasoning_tokens,
    responseModelId: completed.response_model_id,
    run: input.run,
    textTokens: completed.usage.text_tokens,
    timeToFirstTextMs: firstTextAt - requestStarted,
    totalTokens: completed.usage.total_tokens,
    upstreamModel: completed.upstream_model,
    warmup: input.warmup,
  };
};

const summaryMedian = <T>(
  samples: T[],
  value: (sample: T) => number | undefined
): number | undefined =>
  median(
    samples.flatMap((sample) => {
      const resolved = value(sample);
      return resolved === undefined ? [] : [resolved];
    })
  );

const summarize = (
  models: CatalogModel[],
  samples: BenchmarkSample[]
): ModelSummary[] =>
  models.flatMap((model) => {
    const measured = samples.filter(
      (sample) => sample.model === model.id && !sample.warmup
    );
    if (measured.length === 0) {
      return [];
    }
    const clientEffective = summaryMedian(
      measured,
      (sample) => sample.clientEffectiveTextTokensPerSecond
    );
    const clientResponseTime = summaryMedian(
      measured,
      (sample) => sample.clientResponseTimeMs
    );
    const providerEffective = summaryMedian(
      measured,
      (sample) => sample.providerEffectiveOutputTokensPerSecond
    );
    if (
      clientEffective === undefined ||
      clientResponseTime === undefined ||
      providerEffective === undefined
    ) {
      return [];
    }
    const clientOutput = summaryMedian(
      measured,
      (sample) => sample.clientOutputTextTokensPerSecond
    );
    const providerOutput = summaryMedian(
      measured,
      (sample) => sample.providerOutputTokensPerSecond
    );
    const timeToFirstText = summaryMedian(
      measured,
      (sample) => sample.timeToFirstTextMs
    );
    return [
      {
        clientEffectiveTextTokensPerSecondMedian: rounded(clientEffective),
        clientOutputTextTokensPerSecondMedian:
          clientOutput === undefined ? undefined : rounded(clientOutput),
        clientResponseTimeMsMedian: rounded(clientResponseTime),
        model: model.id,
        provider: model.provider,
        providerEffectiveOutputTokensPerSecondMedian:
          rounded(providerEffective),
        providerOutputTokensPerSecondMedian:
          providerOutput === undefined ? undefined : rounded(providerOutput),
        responseModelIds: Array.from(
          new Set(measured.map((sample) => sample.responseModelId))
        ),
        samples: measured.length,
        timeToFirstTextMsMedian:
          timeToFirstText === undefined ? undefined : rounded(timeToFirstText),
        upstreamModel: model.upstreamModel,
      },
    ];
  });

const printSample = (sample: BenchmarkSample): void => {
  const label = sample.warmup ? "warm-up" : `run ${sample.run}`;
  const outputSpeed =
    sample.clientOutputTextTokensPerSecond?.toFixed(1) ?? "n/a";
  const effectiveSpeed = sample.clientEffectiveTextTokensPerSecond.toFixed(1);
  const ttft = sample.timeToFirstTextMs?.toFixed(0) ?? "n/a";
  process.stdout.write(
    `${sample.model} ${label}: ${outputSpeed} visible tok/s, ${effectiveSpeed} effective visible tok/s, ${ttft} ms TTFT through TimberVox\n`
  );
};

const printSummary = (summaries: ModelSummary[]): void => {
  const rows = summaries.map((summary) => ({
    "Effective visible tok/s": summary.clientEffectiveTextTokensPerSecondMedian,
    Model: summary.model,
    Samples: summary.samples,
    "TTFT ms": summary.timeToFirstTextMsMedian ?? "n/a",
    "Visible tok/s": summary.clientOutputTextTokensPerSecondMedian ?? "n/a",
  }));
  process.stdout.write(`\n${JSON.stringify(rows, null, 2)}\n`);
};

const runSequentially = async <Item>(
  items: readonly Item[],
  action: (item: Item, index: number) => Promise<void>,
  index = 0
): Promise<void> => {
  const item = items[index];
  if (item === undefined) {
    return;
  }
  await action(item, index);
  await runSequentially(items, action, index + 1);
};

const main = async (): Promise<void> => {
  const arguments_ = parseArguments(process.argv.slice(2));
  const apiKey = configuredApiKey();
  const catalog = await fetchCatalog(arguments_.baseUrl);
  const models = selectedModels(catalog, arguments_.models);
  const startedAt = new Date().toISOString();
  const samples: BenchmarkSample[] = [];
  const failures: BenchmarkFailure[] = [];

  process.stdout.write(
    `Benchmarking ${models.length} model(s) through ${arguments_.baseUrl}/v1/text/stream\n`
  );

  await runSequentially(models, async (model) => {
    const runIndexes = Array.from(
      { length: arguments_.warmups + arguments_.runs },
      (_, index) => index
    );
    await runSequentially(runIndexes, async (index) => {
      const warmup = index < arguments_.warmups;
      const run = warmup ? index + 1 : index - arguments_.warmups + 1;
      try {
        const sample = await benchmarkSample({
          apiKey,
          baseUrl: arguments_.baseUrl,
          model,
          run: index,
          warmup,
        });
        const normalized = { ...sample, run };
        samples.push(normalized);
        printSample(normalized);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        failures.push({
          ...(error instanceof BenchmarkStreamFailure
            ? error.failure
            : { message }),
          model: model.id,
          run,
          warmup,
        });
        process.stderr.write(
          `${model.id} ${warmup ? "warm-up" : `run ${run}`} failed: ${message}\n`
        );
      }
    });
  });

  const summaries = summarize(models, samples);
  const report = {
    baseUrl: arguments_.baseUrl,
    completedAt: new Date().toISOString(),
    failures,
    methodology: {
      concurrency: 1,
      endpoint: "/v1/text/stream",
      maxOutputTokens,
      metrics: {
        clientEffectiveTextTokensPerSecond:
          "Visible text tokens divided by end-to-end request time through TimberVox, including authentication, Worker processing, provider TTFT, streaming, and network time.",
        clientOutputTextTokensPerSecond:
          "Visible text tokens divided by elapsed time from the first text.delta event to stream.completed at the benchmark client.",
        timeToFirstTextMs:
          "Time from the benchmark client's request start to its first text.delta event from TimberVox.",
      },
      profile: benchmarkProfile,
      protocolVersion: 1,
      runs: arguments_.runs,
      temperature: 0,
      transport: "HTTP Server-Sent Events",
      warmups: arguments_.warmups,
    },
    samples,
    startedAt,
    summaries,
  };

  printSummary(summaries);
  if (arguments_.outputPath) {
    const outputPath = resolve(arguments_.outputPath);
    await mkdir(dirname(outputPath), { recursive: true });
    await writeFile(outputPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
    process.stdout.write(`Wrote ${outputPath}\n`);
  }

  if (summaries.length !== models.length) {
    process.exitCode = 1;
  }
};

await main();
