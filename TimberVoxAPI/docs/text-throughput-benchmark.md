# Text streaming and throughput benchmark

TimberVox exposes two authenticated language-model routes:

- `POST /v1/text` uses AI SDK `generateText` and returns one JSON result. It supports plain text and caller-defined structured object output.
- `POST /v1/text/stream` uses AI SDK `streamText` and returns provider-neutral Server-Sent Events (SSE). It supports plain text output only.

`streamText` and SSE are related, but they are not the same abstraction. `streamText` is the server-side AI SDK call that consumes each provider's streaming protocol. SSE is the HTTP format TimberVox uses to send the normalized result to a client. This keeps provider-specific OpenAI, Anthropic, Gemini, and other event shapes out of the app and benchmark.

Both TimberVox routes share message normalization, model resolution, route-owned reasoning policy, retry policy, output-token limit, timeout, authentication, and usage accounting. Callers may supply unrelated provider options, but they cannot override the route's reasoning effort or thinking mode. Sampling temperature is omitted when the selected reasoning profile does not safely support it. The streaming route records usage under `/v1/text/stream` after its provider stream ends.

## SSE contract

Every SSE frame has `id`, `event`, and JSON `data`. The payload includes `protocol_version: 1` and a monotonically increasing `sequence`.

The ordered event flow is:

1. `stream.started` identifies the TimberVox route, provider, and upstream model.
2. One or more `text.delta` events carry generated text.
3. `stream.completed` terminates a successful stream and includes finish reason, provider-returned model ID, token usage, provider timing, and AI SDK streaming performance.
4. `stream.failed` terminates a failed provider stream and includes a normalized error category, upstream status and provider code when available, whether the failure is safe to retry, and the provider's retry delay when supplied.

There is no provider-specific `[DONE]` marker. A client must treat `stream.completed` or `stream.failed` as terminal.

Example request:

```sh
curl -N https://timbervox.peacockery.studio/v1/text/stream \
  -H "Authorization: Bearer $TIMBERVOX_API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "model": "mistral-mistral-medium-latest",
    "messages": [{"role": "user", "content": "Write one short sentence."}],
    "maxOutputTokens": 64,
    "temperature": 0
  }'
```

## Benchmark

`pnpm benchmark:text` is a live, paid diagnostic command. It fetches the Worker model catalog, then sends every benchmark request through the configured TimberVox `/v1/text/stream` HTTP endpoint. It does not import the provider registry, read provider API keys, or call providers directly.

By default the command uses `https://timbervox.peacockery.studio`, one warm-up, three measured requests per configured language-model route, and concurrency one.

```sh
cd TimberVoxAPI
pnpm benchmark:text --output benchmarks/text-$(date +%F).json
```

Use `--models` for a subset or `--base-url` for a local or preview Worker:

```sh
pnpm benchmark:text \
  --base-url http://127.0.0.1:8787 \
  --models cerebras-gemma-4-31b,google-gemini-3.1-flash-lite
```

The command reads only `TIMBERVOX_API_KEY`. The package script falls back to `Config/keys/TimberVoxAPI.local.xcconfig`, matching the deployed integration tests.

## Metrics

- **Visible output tokens per second** divides returned text tokens by the elapsed time from the first `text.delta` received by the benchmark client through `stream.completed`.
- **Effective visible output tokens per second** divides returned text tokens by total client-observed request time, including TimberVox authentication, Worker processing, provider time to first text, streaming, and network time.
- **Time to first text** measures from the benchmark client's request start through its first `text.delta` event.

The terminal event also preserves AI SDK provider-side output TPS and effective TPS. Those numbers are useful for diagnosing where time was spent, but the product-facing speed measurement is the client-observed TimberVox metric above.

The report keeps every sample and failure, exact TimberVox and upstream model IDs, the model ID returned by the provider, Cloudflare Ray ID when present, token details, timings, and medians. It does not attempt to score dictation correctness or model intelligence. Intelligence data is a separate benchmark source and must not be inferred from throughput.

Failed samples retain the normalized terminal metadata. `rate_limited`, `timeout`, `network`, and `unavailable` failures may be retried by a bounded workflow; `authentication`, `invalid_request`, `empty_output`, and unknown failures are terminal by default. A provider completion that emits only reasoning and no user-visible text becomes `empty_output` rather than a false success. A retry must honor `retry_after_ms` when the provider supplies it. The provider request itself still uses zero hidden AI SDK retries so one benchmark sample corresponds to one measured upstream attempt.

The workload is versioned as `timbervox-text-stream-v2`. Prompt changes require a new profile name so historical comparisons are not silently mixed.
