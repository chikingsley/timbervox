# Transcription contract and product paths

Status: descriptive architecture, updated 2026-07-09. The code and generated OpenAPI
document are canonical. This document explains the boundaries and must not duplicate
provider/model lists that can be read from the Worker.

## Canonical sources

- Public cloud catalog: `GET /v1/models`
- OpenAPI contract: `GET /openapi.json`
- Model and route definitions: `TimberVoxAPI/src/ai/models/`
- Batch execution: `TimberVoxAPI/src/jobs/transcriptions.ts`
- Realtime execution: `TimberVoxAPI/src/routes/realtime.ts` and
  `TimberVoxAPI/src/durable-objects/`
- Mac orchestration: `TimberVox/Core/Dictation/DictationWorkflow.swift`
- Local history: `TimberVox/Core/Database/TranscriptStore.swift`

The Worker owns provider routing, credentials, configured-provider availability,
supported languages, and route capabilities. The Mac consumes the normalized catalog;
it does not maintain a parallel cloud model list.

## Product paths

| Path | Input | Execution | Durable result |
| --- | --- | --- | --- |
| Dictation | Microphone, short form | Batch or realtime | Delivered text plus a simple history record |
| File transcription | Imported audio/video | Async batch | Editable transcript, runs, speakers, timestamps, artifacts |
| Meeting | Microphone + system audio | Realtime preview, then batch finalization | Meeting, master audio, final transcript, notes/minutes |

“Batch” and “realtime” are ASR transports. “Meeting” is a product workflow that composes
both. Dictation means the complete record-to-delivery workflow; transcription means only
speech-to-text.

## Shared batch data path

```text
Mac declares filename, media type, and exact byte size
  -> authenticated POST /v1/uploads
  -> Worker returns signed R2 single-PUT or multipart transfer
  -> Mac uploads bytes directly to R2
  -> authenticated POST /v1/uploads/{upload_id}/complete
  -> Worker verifies ownership and exact R2 object size
  -> transcription job signs a short-lived R2 GET URL
  -> provider-specific URL adapter
  -> normalized text, words, segments, and speaker turns
  -> job result
  -> Mac transform/persist/paste
```

Transfers use a single PUT through 100 MiB and an automatically sized multipart upload
above it. This threshold chooses the simpler R2 operation; it is not a product duration
limit. TimberVox does not proxy media bytes through Worker request memory and does not
load the R2 object into an `ArrayBuffer` for provider dispatch.

AI SDK remains the language-model transform framework. Batch ASR uses owned provider
adapters because the SDK transcription abstraction downloads URL input into bytes before
provider dispatch. Deepgram, Mistral, and ElevenLabs all receive the short-lived R2 URL.

Realtime keeps the same normalized timing/speaker result vocabulary, but not the same
transport implementation. A realtime provider bridge owns connect, audio/control writes,
event parsing, and close behavior; the Durable Object owns session lifecycle, persistence,
and usage.

## Workload authentication and ownership

The Worker authenticates a bearer key against the configured `TIMBERVOX_API_KEYS` secret and derives a stable internal identity:

- `user_id`: API-key accounting owner
- `credential_id`: stable API-key record
- resource ownership for uploads, jobs, and realtime sessions
- idempotency scope and usage attribution

Client-provided ownership headers are not trusted. Missing or unconfigured keys and cross-owner resource access fail closed. Each configured key is registered automatically in the deployed Cloudflare D1 on first use so workload foreign keys and usage accounting remain intact. RevenueCat, StoreKit, installation identity, credential expiration, and provisioning are not part of the Worker boundary.

## Provider direction

- Deepgram Nova-3: initial meeting realtime route; streaming diarization and batch
  finalization are both available.
- Mistral Voxtral Mini Transcribe: primary final/batch candidate for diarization,
  timestamps, and context biasing.
- Mistral Voxtral Realtime: live captions where diarization is not required; the provider
  does not combine realtime with its `diarize` option.
- Groq Whisper: intentionally not a TimberVox transcription route. Groq can remain a
  language-model provider when its credential is configured.

The public catalog exposes only configured providers. Provider availability and exact
language lists stay in code and `GET /v1/models`, not in this document.

## Local meeting research

FluidAudio upstream provides streaming ASR plus online diarization through LS-EEND and
Sortformer. The old TimberVox app contains separate streaming-ASR and diarization
adapters, including incremental timelines and finalization. It also explicitly blocks
their composition in the production workflow. A local meeting path is therefore
plausible, but it is not landed until one audio stream produces correctly aligned words,
speaker segments, and stable final output in the rebuilt app.

## Transcript library direction

The current rebuilt GRDB store is enough for dictation. File and meeting transcription
need a migration that preserves existing rows while adding:

- audio items: source file/master recording and media metadata
- transcription runs: local/cloud model, status, raw/final text, job linkage, errors
- timed segments and optional words with speaker IDs
- context snapshots/attachments used by transforms
- generated artifacts and FTS

Failed and no-speech runs remain visible. Manual reruns create linked runs against the
same audio item. Proven old-app caption renderers are ports to evaluate, not architecture
to bulk-copy.

## Live acceptance

Unit and contract gates support the proof; they do not replace it. The long-media path
is accepted only after real authenticated provider calls using the existing AMI
two-speaker fixture, a real multipart-sized file, and a 10–15 minute live
meeting with network interruption, local-audio survival, final batch reconciliation,
speaker editing, export, and quit/relaunch persistence.

## External references

- Cloudflare R2 uploads: https://developers.cloudflare.com/r2/objects/upload-objects/
- Cloudflare Workers limits: https://developers.cloudflare.com/workers/platform/limits/
- Deepgram diarization: https://developers.deepgram.com/docs/diarization
- Mistral transcription: https://docs.mistral.ai/studio-api/audio/speech_to_text
- FluidAudio: https://github.com/FluidInference/FluidAudio
