# TimberVox rebuild

This is the product and architecture roadmap. `TODO.md` is the canonical active checklist. The old application is preserved read-only under `old-app/`; it is a parts bin for proven behavior, not an architecture to copy wholesale.

## Current truth

The rebuild is no longer a skeleton. The Mac target contains a visible shell, onboarding, cloud dictation, auto-paste behavior, GRDB history, settings, a passive recording indicator, modes, text transforms, app-side RevenueCat purchases, and authenticated batch/realtime Worker clients.

The major runtime boundary refactor is complete. `DictationController` owns observable UI state and commands; `DictationWorkflow` owns record → transcribe → transform → persist → deliver; realtime connection and transcript assembly live under `Core/RealtimeTranscription`; mode persistence and capability interpretation are separated; and the Worker catalog is authoritative for routes, languages, and diarization.

The copied text-transform cleanup is now complete. The obsolete local language-model catalog/provider protocol was removed. The live prompt contract consists of `TextMessage`, presets, prompt assembly, a recording-scoped Dictation context session, and the Worker text-transform route. Context capture now spans record start through stop and includes application/window/focused text, selected-text changes, a three-second pre-recording clipboard window, clipboard changes and attachment metadata, and optional start/end screen OCR.

Automated gates currently pass: Apple Swift Format, strict SwiftLint with zero violations, a real temporary-GRDB persistence integration, the unsigned Debug build, Worker checks, and a real deployed-Worker/deployed-D1 integration. Mocked Swift and Worker contract/unit suites were removed. Signed live acceptance has covered mixed microphone/system capture, local and cloud batch/realtime providers, playback policies, endurance, dual speech, local record-to-delivery, and the five production text-transform presets. These checks still do not prove global shortcuts, macOS focus, paste delivery in third-party apps, permission recovery, or the sample-backed prototype UI.

The production Worker is deployed at `timbervox.peacockery.studio`. It accepts only configured static bearer API keys, exposes the normalized catalog, uses direct signed R2 single/multipart uploads, verifies exact completed size, sends signed R2 GET URLs to batch providers, supports realtime WebSockets through a Durable Object, records usage/ownership in the deployed Cloudflare D1, and has passed production API-key and upload acceptance. Wrangler development uses remote bindings; no local D1 state or local-D1 test path remains.

RevenueCat is app-side purchase UI only and is not part of Worker authorization. The Worker no longer contains entitlement verification, credential provisioning, installation identity, credential expiration, or license tables. This Mac has one development API key in local preferences; release builds may inject a key through `TIMBERVOX_API_KEY`/`TimberVoxAPIKey` without a Keychain or provisioning round trip.

## What remains before the cloud-dictation alpha

The next work is verification and one contained History cleanup, not another general rewrite.

1. Make aggregate capture bounded and explicitly degradable, then accept device/permission/network lifecycle failures.
2. Verify global toggle/stop/cancel, paste into TextEdit and a browser/editor with the TimberVox window closed, and clipboard restoration behavior.
3. Accept application/window, selected text, clipboard boundaries, file/image metadata, and screen OCR in controlled macOS apps.
4. Persist the exact context snapshot and transform request/response metadata with each run, then verify History across quit/relaunch, search, playback, and rerun lineage.
5. Promote accepted prototype designs into production one surface at a time, connected to real runtime state and verified in empty/loading/error/populated states.
6. Repair RevenueCat Test Store products/packages and run purchase, cancellation, failure, entitlement-display, and restore acceptance as a separate app billing lane.

## Product paths

**Dictation** is a short record-to-delivery interaction. It returns text immediately, may apply a mode transform, saves the run, and pastes or copies the result.

**File transcription** imports finite audio or video and creates a durable, editable transcript with timed segments, optional speakers, reruns, and export artifacts.

**Meeting** is a durable session. Live text is provisional; the local master recording is finalized through the file-transcription path for stable speakers, timestamps, notes, and generated artifacts.

A meeting is an explicit app workflow, not a third ASR transport. It composes realtime and batch transcription without requiring a provider-specific `/meetings` API.

## Repository layout

```
TimberVox/       Mac application
TimberVoxAPI/    live Cloudflare Worker
TimberVoxTests/  Mac contract and persistence tests
old-app/         frozen reference implementation
docs/            roadmap, active TODO, architecture, and archived audits
project.yml      XcodeGen source of truth
```

Inside the Mac target:

```
TimberVox/
  App/       application entry points and shell
  Features/  visible product surfaces and their UI controllers
  Core/      shared workflows, domain models, storage, clients, and macOS services
```

A folder is created when real files land, never as a placeholder. A sidebar tab exists only when its visible behavior and runtime path work.

## Current architecture

### Dictation

`DictationController` owns observable state, hotkey registration, and start/stop/cancel commands. `DictationWorkflow` resolves the active mode, owns a context-capture session for the lifetime of the recording, records audio, chooses batch or realtime transcription, optionally transforms text, saves raw/final metadata, and delivers the result.

Ordinary dictation records the microphone to a canonical 16 kHz mono WAV. A mode can additionally include system audio through one private Core Audio aggregate device containing the microphone and a mono process tap. The HAL synchronizes both sources; TimberVox resamples each stream, writes temporary microphone/system stems plus the canonical mixed recording, and sends the same live mixed PCM to realtime transcription when the selected route is realtime. Batch routes consume the mixed recording. Successful short dictation removes its temporary stems after finalization. The old app's misleading either-microphone-or-system behavior is not retained.

Batch transcription is finite request/response orchestration inside `CloudBatchTranscriptionClient`: reserve upload, transfer directly to R2, complete, create a transcription job, and poll only when the synchronous path falls back to the queue.

Realtime transcription uses `CloudRealtimeTranscriptionClient` for the authenticated WebSocket and binary PCM/JSON wire contract. `RealtimeTranscriptionSession` owns the app-side lifecycle, while `RealtimeTranscriptAssembler` owns partial/final event composition.

### Cloud clients

`CloudHTTPClient` owns common JSON requests, static bearer authorization, signed uploads, and response validation. `CloudClients` is a composition container—not a barrel export—that creates batch, catalog, transform, and fresh realtime clients with the same base URL and `URLSession`.

`CloudModelCatalog` contains the decoded Worker contract, `CloudModelCatalogClient` fetches it, and `CloudModelCatalogStore` caches cloud state. `TranscriptionModelCatalogStore` merges those Worker-authoritative routes with the compiled local catalog for Modes and History without sending local audio through the Worker. The Mac never invents a cloud provider route, language list, or diarization capability absent from the Worker catalog.

### Text transforms and context

`TextTransformPreset` defines the built-in and custom instructions. `TextTransformPromptBuilder` produces real system/user messages from the transcript and enabled context. `CloudTextTransformClient` serializes those messages to the Worker, whose Zod request contract feeds AI SDK `generateText`. The Worker requests a Zod-validated `{ text }` structured output and preserves the existing clean `text` API response for Mac clients.

The inherited Superwhisper response delimiter is no longer part of the prompt, Worker, or Mac contract. Structured output is the only supported text-transform response path.

`SystemDictationContextProvider` supplies current application/window, focused element, selected text, language/time/locale/computer, and local user information. `DictationContextCaptureService` wraps it in a recording-scoped session, monitors clipboard and selection changes every 300 ms, retains a three-second pre-recording clipboard window, records copied file/image metadata, and optionally captures start/end screenshots with Vision OCR. Screenshot files and clipboard images are local context attachments; the text prompt receives OCR and attachment metadata, not raw multimodal image input. Application and selection access depend on Accessibility permission; screen OCR depends on Screen Recording permission. Vocabulary remains unimplemented.

### Persistence

GRDB stores dictation records under `~/Library/Application Support/TimberVox/timbervox.sqlite`. The current schema preserves final text, raw text when transformed, recording metadata, mode/model/provider/language/latency, transform metadata, and the audio path.

The immediate persistence expansion records the exact dictation context snapshot, transform request/response metadata, and attachment references so a transformed run can be inspected and reproduced. The larger File Transcription expansion adds audio items, multiple linked transcription runs, timed segments/words, speakers, artifacts, errors, manual-rerun lineage, and FTS. Failed and no-speech runs remain visible rather than disappearing.

## Later product slices

### Local models

The unified catalog and production dictation workflow now contain FluidAudio-backed Parakeet batch and Nemotron realtime routes. A package lifecycle discovers persistent FluidAudio assets, distinguishes downloaded files from models that successfully loaded, records FluidAudio-version-specific verification, prepares only unverified assets, and deletes shared assets safely. FluidAudio 0.15.5 fixes the former English Nemotron zero-shape load failure. On the Apple M1 test machine, every exposed Parakeet and Nemotron route now downloads, loads, and transcribes real speech; a complete offline system-audio record-to-delivery run also passed through persistence and clipboard delivery. The multilingual encoder still reports an Apple Neural Engine compiler failure before Core ML falls back and completes inference, so this is functional but not clean ANE execution. The remaining vertical slice is lifecycle UI, long/silent/cancel/timeout acceptance, broader Songbird language coverage, and measured storage/performance guidance. VAD, diarization, and keyword spotting remain later research until accepted as complete workflows.

### Sound feedback

Port start/stop/cancel sounds, resources, lifecycle, and Settings controls together.

### Hot mic and push-to-talk

Hot mic needs explicit buffer semantics and the realtime path. Push-to-talk needs the CGEvent tap and Accessibility UX. Do not add commands or settings before their runtimes exist.

### Dictionary and vocabulary

Resume after Modes and History are stable. Vocabulary must participate in actual context capture and transform acceptance rather than exist as dead settings data.

### File transcription

Reuse the direct R2 single/multipart upload and short-lived provider URL ingestion. Do not create a second long-media upload path. Build import, progress, cancellation, editable timed transcript, speaker renaming, playback seeking, rerun, and TXT/Markdown/JSON/SRT/WebVTT export.

Done means the AMI two-speaker fixture and a real long recording survive upload, provider processing, speaker editing, quit/relaunch, rerun, and export.

### Meetings

Capture microphone and system audio into a local master. Deepgram Nova-3 is the initial provisional live path because it supports streaming diarization. When the meeting ends, run the master through File Transcription and compare Deepgram batch with Mistral Voxtral Mini for the final diarized transcript. Summaries, minutes, and action items consume the final transcript, not the provisional stream.

FluidAudio streaming ASR plus LS-EEND/Sortformer diarization remains a research path. Separate adapters exist in the old app, but timestamp/speaker composition is not implemented or accepted in this rebuild.

## Billing and ship preparation

The intended accountless product split is `cloud_access` as a recurring managed-cloud purchase and `local_pro` as a one-time local purchase. Apple/RevenueCat remains an app concern. The Worker is intentionally decoupled from billing: configured static API keys authorize execution, while the deployed Cloudflare D1 records ownership, usage, and future key-scoped quotas.

App Store Connect contains the Cloud Access monthly subscription and Local Pro non-consumable for the universal app. RevenueCat contains the corresponding project, app, entitlements, products, packages, and offering, but the Debug Test Store mapping still needs repair and Apple's App Store Connect API key currently returns `401 NOT_AUTHORIZED` upstream. Do not generate more Apple keys merely to chase propagation.

Before shipping: complete Test Store and sandbox purchase/restore acceptance, verify universal purchase after the iOS app exists, enable the intended App Store signing/sandbox configuration, add the App Review screenshot, rotate the Cloudflare and R2 credentials supplied during setup, decide how release builds receive the static API key, and use build number 79 or later.

## Parts-bin map

- Hotkey tap and push-to-talk: `old-app/apps/mac/Sources/Services/KeyEventMonitorService.swift` plus the old core hotkey domain/logic.
- Paste behavior: `old-app/apps/mac/Sources/Services/PasteboardService.swift`.
- Rich transcript persistence: `old-app/packages/timbervox-core/Sources/TimberVoxCore/Transcripts/`.
- Local ASR: old Parakeet, FluidAudio, and streaming clients plus the old transcription core.
- Sound feedback: `old-app/apps/mac/Sources/Services/SoundEffectsService.swift`.
- Recording indicator ideas: `old-app/apps/mac/Sources/Prototype/Recorders/`.
- Settings concepts: the old core settings model, mined selectively rather than ported wholesale.
- Caption/export primitives: old transcript/caption renderers, ported only with generated-artifact verification.

## Durable decisions

- Use stock SwiftUI/AppKit controls first and isolate custom interaction only when stock controls cannot satisfy it.
- Use Apple `swift format` plus strict curated SwiftLint; do not introduce a second formatter or a suppression baseline.
- Dictation means the whole record-to-delivery workflow. Transcription means only speech-to-text.
- Every exposed ASR route has an exact supported-language list. Unknown language support excludes the model.
- Transport support derives from route existence. Route-specific capabilities such as diarization are explicit fields.
- WAV is the current recording format: uncompressed PCM, native to produce, accepted by all current providers, and roughly 32 KB/s at 16 kHz mono 16-bit.
- There is no arbitrary TimberVox duration limit. Enforce known media types, exact byte size, R2 multipart constraints, provider maximums, credential quotas, and rate limits.
- Batch audio goes Mac → signed R2 upload → signed provider URL. It does not pass through Worker request memory.
- AI SDK remains the language-model transform framework. Provider-specific batch ASR URL adapters are owned by TimberVox because the generic transcription abstraction downloaded URL inputs into Worker memory.
- Carbon hotkeys remain the default until push-to-talk genuinely requires a CGEvent tap.
- Do not ship dead UI, speculative folders, silent fallbacks, or partially wired old-app subsystems.
