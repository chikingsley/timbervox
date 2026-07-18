# Changelog

All notable changes to the TimberVox rebuild are recorded here. The frozen pre-rebuild history remains available in [`old-app/CHANGELOG.md`](old-app/CHANGELOG.md).

## Unreleased

### Added

- Rebuilt the macOS application around a focused `DictationController`, record-to-delivery `DictationWorkflow`, explicit batch and realtime clients, Worker-authoritative model catalog, mode persistence, GRDB History, onboarding, permissions, purchases, and passive recording indicator.
- Added accountless RevenueCat identity for app-side purchase state. Worker authorization was subsequently decoupled from RevenueCat and reduced to configured static API keys.
- Added direct signed R2 single and multipart uploads, exact-size completion, provider URL ingestion, normalized batch/realtime transcription results, ownership, usage accounting, and authenticated realtime WebSockets.
- Added recording-scoped context capture for the frontmost application/window, focused and selected text, a three-second pre-recording clipboard window, during-recording clipboard changes, file/image metadata, start/end screenshots, and on-device Vision OCR.
- Added Zod-validated structured text-transform output and production presets for Super, Message, Note, Email, Meeting, and Custom modes. The inherited response tags and legacy cleanup path were removed.
- Added per-mode playback policies: Keep playing, Lower volume, Mute, and Pause media, with exact restoration on stop or cancel.
- Added a connected macOS UI prototype behind `--prototype`. It is intentionally sample-backed design evidence and is not production runtime UI.
- Promoted the accepted three-column Modes design into production with the real mode store and Worker catalog, native mode editing/duplication/deletion, preset explanations, and configurable Custom prompt context.
- Added a unified app-side transcription catalog that merges Worker-authoritative cloud routes with three executable FluidAudio products: Hummingbird, Nightingale, and Songbird. Each local product pairs an exact Parakeet batch route with an exact Nemotron realtime route and publishes route-specific languages and capabilities.
- Added local Parakeet batch and Nemotron streaming execution to the production dictation workflow, including first-use FluidAudio model loading, offline History reruns, and quality/response guidance with explicit evidence provenance.
- Added a local model package lifecycle for Hummingbird, Nightingale, and Songbird with exact batch/realtime assets, persistent load-verification markers, combined progress, cache rediscovery, and reference-aware deletion of shared assets.

### Changed

- Replaced the previous monorepo app/package layout with root `TimberVox`, `TimberVoxTests`, and `TimberVoxAPI` targets while retaining the former implementation under `old-app` as a read-only parts bin.
- Standardized Swift code with Apple `swift format`, strict curated SwiftLint, Swift 6 concurrency checks, real integration/acceptance tests, and an unsigned build gate.
- Removed mocked and deterministic Swift unit tests plus the Worker's mocked contract, adapter, RevenueCat, route, and local-auth suites. Retained tests now exercise real SQLite/GRDB, the deployed Worker and Cloudflare D1, real macOS devices and permissions, real model assets/inference, or real deployed providers.
- Replaced stop-time microphone/system file mixing with one private Core Audio aggregate device containing the default microphone and a mono process tap. Both sources are independently normalized to canonical 16 kHz mono, mixed live, written to stems/master, and sent to realtime transcription from the same stream.
- Kept system-audio modes on realtime when the selected Worker route supports realtime; batch and realtime now consume the same canonical capture.
- Simplified the Mac cloud boundary into shared HTTP authorization plus focused catalog, batch, realtime, and text-transform clients.
- Preserved raw and transformed text plus mode/model/provider/language/latency/audio metadata in GRDB.
- Made automatic-language support an explicit per-route Worker catalog capability. Model or transport changes now preserve supported languages, otherwise fall back to Automatic when published, then English, then the route's first supported language.
- Made built-in text transforms consume all available context by contract while Custom starts from the app's default prompt and captures only the context sources selected for that mode.
- Corrected the inherited Parakeet v3 language catalog to NVIDIA's published 25-language set and kept Songbird's Parakeet and Nemotron language lists separate so transport changes cannot advertise unsupported languages.
- Preserved saved cloud model selections while the Worker catalog is unavailable or incomplete; fallback normalization now waits for a successful authoritative cloud catalog load.
- Distinguished local model files that merely exist from models that have successfully loaded. Rebuilds and relaunches reuse Application Support caches, but only a completed preparation earns the durable verified state.
- Upgraded FluidAudio from 0.15.4 to 0.15.5, which replaces the failing Core ML Nemotron mel preprocessor with native Swift extraction. Local verification markers are now scoped to that runtime version so an older successful load cannot silently authorize a changed model runtime.
- Bounded interactive text transforms to one provider attempt and ten seconds. This removes the AI SDK's two default retries, so an overloaded provider cannot turn one failed dictation transform into a roughly 30-second stall.
- Replaced per-callback audio-array allocation and unbounded processing dispatch with a preallocated atomic single-producer/single-consumer bridge. The bridge holds at most half a second of synchronized microphone/system chunks and records dropped or oversized chunks as degraded capture.
- Added aggregate-capture health monitoring after startup. A stopped microphone-plus-system stream now fails the active dictation visibly and restores workflow state; legitimate silent buffers remain healthy and the app never changes that recording to microphone-only.
- Added three-attempt bounded retry for transient signed-R2 PUT failures with short backoff. Exhaustion preserves the completed local recording and reports a retryable workflow failure instead of discarding the audio.
- Reduced local-model route-switch peak memory by releasing the previous Core ML graph before loading its replacement. Songbird now reuses one loaded graph across languages in the same Latin/full asset variant and applies FluidAudio's explicit language prompt, including exact `ja-JP` and `zh-CN` mappings for the app's bare language codes.
- Removed Wrangler-local D1 state, migrations, scripts, and tests. Wrangler development and integration verification now use only deployed Cloudflare resources.
- Moved Worker authorization to environment-scoped D1 credentials while preserving workload ownership and accounting in D1.
- Restored the local voice-model active-duration setting as a real runtime policy. Only the last requested batch or realtime graph remains resident; switching transport releases the prior graph, and Settings offers one, five, or fifteen idle minutes plus Keep loaded.

### Fixed

- Fixed realtime transcript assembly dropping legitimately repeated final phrases by deduplicating only provider flushes for the same audio-window start time.
- Fixed recording finalization so a recorder/transcription failure restores playback, cancels realtime work, and clears the active workflow session.
- Fixed app-owned clipboard-image and OCR-screenshot copies accumulating indefinitely; expired clipboard snapshots and completed/cancelled dictations now remove those copies without touching user files.
- Removed unknown-language fallbacks, the unsupported GLM ASR model, public unauthenticated workload routes, untrusted client-ID ownership, Worker-buffered batch audio, and forced transcript-store initialization.

### Verified

- Passed signed microphone-plus-system signal acceptance, source isolation, canonical mixed WAV creation, output-device switching, cancellation/restart, and a ten-minute bounded-memory capture endurance run on 2026-07-10.
- Passed production Deepgram realtime and batch transcription from the same mixed recording, a minute-long realtime soak, and controlled dual-speech acceptance with distinct microphone and system phrases on 2026-07-10.
- Passed live Keep playing/Lower volume/Mute signal measurements and QuickTime Pause/resume acceptance on 2026-07-10.
- Passed a five-mode deployed-Worker transform matrix for Super, Message, Note, Email, and Custom using fixed production requests; request/result artifacts were saved under `/tmp/timbervox-acceptance` on 2026-07-10.
- Passed production ownership, signed R2 single/multipart upload, signed provider URL, and real transcription-job acceptance under the earlier credential design.
- Passed deployed static-key authorization against the production Worker and production Cloudflare D1 before and after the schema cleanup migration; unauthenticated usage returned 401 and the configured key returned the real usage document with HTTP 200.
- Passed the five-preset macOS text-transform acceptance through the deployed static-key Worker boundary in 5.557 seconds; request/result artifacts are under `/tmp/timbervox-acceptance/20260710-170850-transforms`.
- Passed the five-preset transform acceptance again in 5.228 seconds using only the API key embedded from the ignored xcconfig, after removing the former UserDefaults fallback.
- Passed the unified local/cloud route-contract suite, strict formatter/linter gates, and unsigned app build with FluidAudio 0.15.5 linked.
- Passed real Hummingbird batch acceptance on an Apple M1: Parakeet 110 loaded from its persistent FluidAudio cache, survived backend recreation, and transcribed a generated English fixture with network downloads disabled on 2026-07-10.
- Passed real inference for every exposed local route on an Apple M1: Parakeet 110, Parakeet v3, Nemotron English 560 and 1120, and Nemotron Multilingual 1120 with both Latin and full Japanese assets. The multilingual encoder reports an Apple Neural Engine compiler failure and succeeds through Core ML fallback; it is functional but not clean ANE execution.
- Passed a complete offline local dictation on 2026-07-10: synthesized system speech was captured through the production aggregate recorder, transcribed by Hummingbird, persisted to an isolated GRDB store, and delivered to the clipboard. The inspectable transcript remains under `/tmp/timbervox-acceptance/20260710-143543-local-workflow`.
- Passed six production aggregate-recorder hardware tests after the bounded-bridge change, including real delayed system-audio start/stop and a deliberately slow realtime consumer that produced bounded, explicitly reported degradation instead of queued memory growth.
- Verified the Google AI Studio key and AI SDK integration on 2026-07-10. `gemini-3.5-flash` exceeded the ten-second product ceiling even with minimal thinking, so the Worker catalog now exposes only the explicit stable `gemini-3.1-flash-lite` Google route instead of 3.5 or moving `*-latest` aliases; the replacement completed the real structured-output path in 830 ms.
- Passed local failure and endurance acceptance on 2026-07-10 using real FluidAudio execution: four seconds of silence returned no speech, a 51-second synthesized dictation retained its final phrase, cancelling a Nemotron session allowed a clean real restart, and an offline missing-model preparation failed in 28 ms.
- Re-ran all four real local failure/endurance paths after adding last-requested model retention. Hummingbird batch inference was replaced by Nemotron realtime, cancel/restart remained clean, and the suite passed in 46.105 seconds.
- Passed Songbird across German, English, Spanish, French, Italian, and Portuguese through both real Parakeet batch and Nemotron realtime inference, plus Japanese and Chinese realtime inference with prompt IDs 10 and 4. Measured logical asset sizes were 483,256,769 bytes for Parakeet v3, 611,340,223 bytes for Nemotron Latin, and 664,144,423 bytes for Nemotron full; artifacts are under `/tmp/timbervox-acceptance/20260710-163748-songbird-languages`.
- Passed an in-process route-switch sequence from Nemotron English 1120 to English 560 to the full Japanese multilingual model after releasing superseded Core ML graphs; all three real transcriptions completed without the earlier process termination.
- Passed the deployed-provider recording acceptance after the upload-retry change on 2026-07-10: one real mixed recording completed both authenticated Deepgram realtime and signed-R2 batch transcription. Artifacts are under `/tmp/timbervox-acceptance/20260710-164419-provider`.
