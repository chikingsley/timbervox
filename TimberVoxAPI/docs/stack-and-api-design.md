# TimberVox Cloud Stack

This package is the TimberVox cloud boundary. The macOS app talks to this API for cloud language-model transforms, ASR, realtime ASR, usage logging, uploads, and jobs.

## Agreed Stack

- Runtime: Cloudflare Workers.
- Language: TypeScript.
- Package manager: pnpm.
- Web framework: Hono.
- Validation: Zod.
- Route contracts and OpenAPI: `@hono/zod-openapi`.
- Docs UI later: `@scalar/hono-api-reference`.
- Formatting and linting: Biome through Ultracite.
- Tests: Vitest.
- Cloud integration tests: Vitest against the deployed Worker and deployed Cloudflare D1.
- Deployment and remote development runtime: Wrangler.
- Worker types: Wrangler-generated `worker-configuration.d.ts`.

The initialized package has pnpm, Ultracite, and Biome. This is a Worker API package, so the Biome config uses the Ultracite core and Vitest presets.

## API Shape

- Hono owns routing, middleware, and route composition.
- Zod owns every external input and output boundary.
- `@hono/zod-openapi` owns route contracts that become public API.
- Provider code receives typed values from route handlers.
- Public model IDs are TimberVox IDs.
- Provider model IDs stay behind the API boundary.
- Direct HTTP handles language-model transforms and batch ASR provider calls.
- WebSockets handle realtime ASR through Durable Objects.
- Public AI routes use TimberVox product workflows under the TimberVox domain.

Source layout:

```text
src/
  index.ts
  bindings.ts
  ai/
    text-transform.ts
    registry.ts
    transcription/
      registry.ts
      service.ts
      types.ts
    realtime/
      bridge.ts
      normalize.ts
    models/
      batch-asr-models.ts
      batch-asr-options.ts
      catalog.ts
      language-models.ts
      map.ts
      realtime-asr-models.ts
      realtime-asr-options.ts
      types.ts
    deepgram/
      realtime/
      transcription/
    elevenlabs/
      transcription/
    mistral/
      realtime/
      transcription/
  http/
    json.ts
  durable-objects/
    realtime-result.ts
    realtime-session.ts
  jobs/
    consumer.ts
    db.ts
    enqueue.ts
    transcriptions.ts
  lib/
  routes/
    uploads.ts
    transcriptions.ts
    jobs.ts
    text-transforms.ts
    realtime.ts
  uploads/
    limits.ts
    service.ts
    signing.ts
```

File roles:

- `index.ts`: creates the Hono app, mounts routes, and exports the Worker `fetch` and Queue handlers.
- `bindings.ts`: central TypeScript type for Cloudflare bindings: D1, R2, Queues, provider secrets, and job rows.
- `ai/transcription/`: normalized remote-media batch ASR contract and provider registry.
- `ai/realtime/`: normalized realtime event contract and provider bridge registry.
- `ai/text-transform.ts`: language-model transform execution. The app/Core renders prompt messages; the cloud route executes them.
- `ai/models/language-models.ts`: TimberVox language model IDs mapped to upstream provider model IDs.
- `ai/models/batch-asr-models.ts`: TimberVox batch ASR model IDs mapped to upstream provider model IDs.
- `ai/models/realtime-asr-models.ts`: TimberVox realtime ASR model IDs mapped to upstream provider model IDs.
- `ai/models/batch-asr-options.ts`: accepted batch ASR request option names grouped by provider.
- `ai/models/realtime-asr-options.ts`: accepted realtime ASR request option names grouped by provider.
- `ai/models/catalog.ts`: public model catalog for `GET /v1/models`.
- `ai/*/realtime/`: provider-specific realtime WebSocket clients and event schemas.
- `ai/*/transcription/`: provider URL request/response adapters.
- `http/`: shared HTTP response helpers.
- `durable-objects/`: long-lived Cloudflare Durable Object classes such as realtime WebSocket sessions.
- `routes/`: HTTP contracts. Route files parse input, call services/providers, and return TimberVox responses.
- `jobs/`: D1-backed queue job creation, idempotency, queue consumer, status, and transcription job orchestration.
- `uploads/`: D1 reservations, signed R2 single/multipart transfers, completion verification,
  and signed provider reads.

Local references:

- `cloudflare-sw-compat`: small Hono app factory, Zod parsing, provider request builders, and live request-shape tests.
- `cloudflare-api`: full Cloudflare API reference with OpenAPI, Scalar docs, auth, client metadata, D1, R2, Queues, Durable Objects, jobs, uploads, captions, and deployed live tests.

## Cloudflare Primitives

D1:

- durable relational metadata
- static API-key owners, requests, jobs, usage, and model routes
- upload metadata, job status, canonical result JSON, usage, auth, and routing state

R2:

- source audio and video
- optional debug captures

Queues:

- batch/file transcription
- transcription plus language-model transform
- provider retry/backoff
- webhook and billing fanout

Durable Objects:

- realtime WebSocket coordination
- provider WebSocket proxying
- session duration metering
- transcript event normalization
- final realtime result persistence

## Route Families

Request/response:

```text
GET  /health
POST /v1/text-transforms
```

Uploads and jobs:

```text
POST /v1/uploads
POST /v1/uploads/{upload_id}/complete
POST /v1/transcriptions
GET  /v1/jobs/{job_id}
```

Realtime:

```text
GET /v1/realtime
```

All workload routes use `Authorization: Bearer <api-key>`. Accepted keys come only from the `TIMBERVOX_API_KEYS` Worker secret. Billing and purchase state are outside this API.

## First Build Step

1. Add dependencies and TypeScript/Wrangler config.
2. Add `src/index.ts` with `/health`.
3. Add a Zod/OpenAPI route skeleton.
4. Add model registries for ASR models and language models.
5. Add one live Vitest test against the deployed Worker and deployed Cloudflare D1.
6. Add Mistral-backed text transform as the first real language-model route.
