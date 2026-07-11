# TimberVox TODO

Work items only. Rules and resources live in `AGENTS.md`; landed changes in `CHANGELOG.md`; history in `docs/archive/`. Every item below was verified against the code on 2026-07-04 (fresh build: zero errors; 78 Core + 18 app tests green). Nothing goes on this list without file:line evidence.

## Broken UI

- [ ] 2026-07-08 Chi rejection: the current Keyboard Shortcuts layout is rejected. Paste Last Transcript must not sit near the primary recording controls; it should move to the bottom or into its own separate History/Paste section, and it must remain unset by default. [B]
- [x] 2026-07-08 Chi rejection: Hot Mic Paste and Hot Mic Dump do not work as ordinary shortcut rows in the Configuration list. They now live under a dedicated Configuration > Hot Mic section using the old colored command-card treatment, with the real Hot Mic toggle and the separate Hot Mic sidebar pane removed. [B]
- [ ] 2026-07-08 Chi rejection: Push to Talk alone is not enough. Toggle Recording / toggle on-off must be present and real; chat-history evidence says the prior Shortcuts V2 direction had Push to Talk / Toggle Recording / Change Mode together, while later production notes left Toggle Recording / Change Mode / Mouse as display-only because there was no engine path yet. [A]
- [ ] 2026-07-08 Chi rejection: Super Fast Mode should not be a confusing exposed Sound setting. Decide whether the reliability behavior should be automatic, folded into model/capture internals, or explained elsewhere before showing any user-facing toggle. [B]
- [ ] 2026-07-08 Chi rejection: Automatically check for updates and Automatically download updates feel like the same setting in this app and should not appear as two adjacent toggles without a product reason. Sparkle documents them as separate settings (`SUEnableAutomaticChecks` schedules checks; `SUAutomaticallyUpdate` downloads/installs when possible), but TimberVox still needs a simpler UI decision. [B]
- [ ] 2026-07-08 Chi rejection: settings organization is too complex for a simple dictation app. Do not continue piecemeal wiring until Configuration, Sound, Hot Mic, Shortcuts, Updates, and History/Paste are re-grouped around the actual user workflows. [B]
- [x] 2026-07-04: The popover system was fixed in one pass. `OptionMenu` now caps at six rows then scrolls (`OptionMenuMetrics`; the bound lives inside the component), every call site lost its width/panelWidth overrides (the Preset menu keeps `panelWidth: 204` + `showsAllRows: true` as the ONE documented exception), the voice-model picker sizes to its content (`minWidth` 300, fixed frame removed), and both presentation paths (`FloatingHost` in-window and `FloatingWindowBridge` child panels) propose content its ideal size via `.fixedSize()`. Verification previews added in OptionMenu.swift and ModesModelPicker.swift; build and lint green.
- [ ] Chi's popover pass in the REAL app (child panels cannot render in previews) — every dropdown in Configuration, Sound, Modes, and History filters: size, position, clipping, hover, click-away, screen edges. [C]

---

## Architecture cleanup — captured 2026-07-08

- [ ] Split `apps/mac/Sources/App` so app lifecycle, menu-bar hosting, onboarding, updater UI, debug deep links, debug state reporting, and diagnostics do not live in one catch-all folder; resolve the confusing `App` versus `Features/App` naming collision by renaming the mounted shell area or moving shell files out of `Features/App`. [A]
- [ ] Decide the debug/diagnostics boundary explicitly: keep `timbervox-debug://` deep links and debug-state JSON as live test infrastructure for `just live-suite`, but move them under a clearly named debug/app-control area and rename or remove the one-line diagnostics bootstrap logger. [A]
- [ ] Split `apps/mac/Sources/Clients` into responsibility folders for cloud API transport, FluidAudio batch ASR adapters, FluidAudio streaming adapters, FluidAudio support-model adapters, and audio preparation; move `ParakeetClipPreparer` out of `Clients` because it is not a client. [A]
- [ ] Audit the support-model clients before surfacing them as product features, because VAD, diarization, and keyword-spotting model management exists while the production workflow still rejects those local composition modes. [A]
- [ ] Rename the live streaming model surface from “Streaming Preview” if Hot Mic streaming is shipping behavior, or move the streaming surface back to Prototype if it is not shipping behavior. [B]
- [ ] Create a no-behavior-change reorganization of `apps/mac/Sources/Services` by real responsibility, such as composition, persistence, recording/capture, transcription/workflow, automation/input, media/pasteboard, and context capture; do not move behavior before preserving a call-site map. [A]
- [ ] Rename misleading service files to match their primary types before broad symbol renames, including `RecordingService.swift` to `RecordingClientLive.swift`, `TranscriptionService.swift` to `TranscriptionClientLive.swift`, and `StreamingAudioService.swift` to an always-on-specific name. [A]
- [ ] Decide what `apps/mac/Sources/State` means, because actual runtime state lives mostly in observable stores and `SettingsManager`; either dissolve the passive value files beside their owners or rename the folder to something explicit like `StateModels`. [A]
- [ ] Split `SettingsManager` into a persisted settings repository and a separate runtime/session state owner, because it currently mixes JSON persistence with hotkey capture flags, model bootstrap state, permission state, legacy import state, and transient UI state. [A]
- [ ] Move non-store helpers out of `apps/mac/Sources/Stores`, including `ForceQuitCommandDetector`, `StopRecordingContext`, and `TranscriptFinalizationPayload`, because they are transcription policies or payloads rather than stores. [A]
- [ ] Regroup mounted feature folders around the product workflows rather than implementation leftovers: shell/navigation, shortcuts, recording, updates/about, history/paste, models, modes, and prototype-only experiments should have unambiguous homes. [B]
- [ ] Clean mounted UI ownership boundaries by moving `ModelLibraryAdapter` into `Features/Models`, splitting or renaming `Keycap.swift` around the real `ShortcutRecorder` state machine, and removing empty-action defaults from shared command primitives. [A]
- [ ] Quarantine mounted Modes mocks until they are real, including create-extra-mode, mode shortcut, and Activate for apps; either move them back to Prototype or wire Core `Mode` persistence and dispatch end to end. [A]
- [ ] Add a short architecture note defining the current meanings of `App`, `Features`, `Prototype`, `UI`, `Clients`, `Services`, `Stores`, `State`, `SettingsManager`, `TranscriptStore`, and `HistoryStore` so future agents stop re-deriving the same boundaries. [A]

---

## Dead controls — resolved 2026-07-04 (each was wired for real or removed from the UI)

Wired to real behavior (settings defaults preserve prior behavior; Chi verifies feel):
- [x] "Paste result text" now gates the paste: off = transcript copied to clipboard only (`TranscriptionStore.finishTranscription`). [C to feel]
- [x] Clipboard restore behavior consumed: Default = restore unless copy-to-clipboard is on (previous behavior), Restore = always, Bypass = never (`PasteboardService.shouldRestoreClipboard`).
- [x] "Lower volume" playback now actually ducks to 25% instead of full-muting (`RecordingClientLive+MediaControl.swift`, `RecordingAudioHardware+Volume.swift`), restore path unchanged.
- [x] Auto increase microphone volume: raises the system-default input device to max at record start and restores it after (`raiseInputVolumeToMax`/`restoreInputVolume`); skipped when a specific mic is selected, matching the control's hint.

Removed from the UI until their feature exists (settings fields kept; restore each row when wiring lands):
- [x] Silence removal and Dynamic normalization rows (SoundPane) — restore with the VAD/normalization work in the wiring matrix.
- [x] Error logging row — restore with the sink decision.
- [x] Start Recording on Menubar Click and Always close rows — menubar click needs an NSStatusItem rewrite (SwiftUI MenuBarExtra menu-style can't intercept left-click); always-close needs defined semantics.
- [x] Hold shift to auto-send row — restore with the auto-send feature.
- [x] Voice model active duration section — restore with the model keep-alive/unload timer.
- [x] App folder location section — the "Change folder..." button did nothing and the shown path (~/Documents/TimberVox) was not where data lives.
- [x] Agent Plugins section — "Install" buttons did nothing; restore with the agent-plugins feature.
- [x] Show experimental models section — restore when the library adapter exposes an experimental flag.
- [x] Modes rows: Realtime (restore with the app-side realtime client), Identify Speakers (restore with diarization), Autocapitalize Insert (restore with the insert post-step); the backing `ModeDraft` fields were removed with them.

Wired and confirmed working, for the record: playback-pause-on-record, system-audio capture (`SystemAudioTapRecorder.swift`), model prewarm (`AppStore.swift:326`), show Dock icon (`TimberVoxAppDelegate.swift:326-330`).

- [ ] Unit tests for the newly wired branches (paste gate, restore decision, duck factor, input-volume raise) as part of the settings-persistence audit. [A]

## Dead controls — found and REMOVED from the app 2026-07-08 (same rule as 07-04: the app mounts only wired UI; no feature flags — each row below restores by being wired for real)

- [x] 2026-07-08: all surfaces below were physically removed from the app shell/panes; whole-pane mocks moved to `Prototype/` for continued design work via #Preview. No conditionals were added anywhere.
- [ ] License pane — whole-pane visual mock, now at `Prototype/Panes/LicensePane.swift`; sidebar license card + rail icon deleted from `AppShellView`, `.license` tab removed. Restore: build the RevenueCat/license transport, wire purchase/restore/entitlement for real, move the pane back into Features/ and remount. [B]
- [ ] Recording-window surface chooser — mock layer now at `Prototype/Recorders/ConfigurationRecordingSurfaces.swift` (incl. `ConfigurationRecordingWindowRow`); chooser row, demo row, and header pill deleted from ConfigurationPane. Restore: recording-surface productionization (`docs/recorders/`) with a persisted, consumed setting. [B]
- [x] 2026-07-08: The separate Hot Mic pane stayed removed. Configuration now owns Hot Mic through the old blue/green/orange command cards, with the blue Start / Stop card wired to the real Hot Mic toggle and Paste and Dump wired to their shortcut recorders. [A]
- [ ] Configuration shortcut rows Toggle Recording, Cancel Recording, Change mode, Mouse — deleted along with the dead `shortcutKeys` state and enum cases; Push to Talk, Paste Last Transcript, Hot Mic Paste, and Hot Mic Dump are mounted and wired. Restore: wire each deleted shortcut to the hotkey engine (defaults were ⌥␣ / esc / ⌥⇧K / mouse — recorded here so nothing is lost). [A]
- [x] 2026-07-08: Configuration now keeps Push to Talk and Paste Last Transcript in Keyboard Shortcuts, while Hot Mic Paste and Hot Mic Dump live in the dedicated Hot Mic section. Paste Last Transcript defaults to unset and reset clears it instead of restoring a concrete key. [A]
- [ ] Home URL-intake field, What's New section, and the "Add Vocabulary" quick action (pointed at the removed Dictionary tab) — deleted. Restore: URL transcription intake feature; a real changelog source; Dictionary shipping. [B]
- [ ] Dictionary tab — removed from the sidebar (`ActiveTab`); the pane stays at `Prototype/Panes/PrototypeDictionaryPaneV2.swift` for Chi's design pass. Restore: design pass + real vocabulary persistence, then remount. [B]
- [x] 2026-07-08: Home Start Recording tile restored and wired to the real `TranscriptionStore` start/stop path; the tile switches to Stop Recording while active. [A]
- [x] 2026-07-08: Home Hot Mic tile was removed again after Chi rejected duplicate Hot Mic surfaces; Configuration owns the Hot Mic toggle and the existing `AlwaysOnStore` still observes the same setting. [A]
- [ ] Home tiles Transcribe Files / System Audio — still removed because they need real actions before remounting: file-transcription intake and system-audio capture entry. [A]
- [x] 2026-07-08: `ModesTip` "Dismiss" wired — dismisses for the session (`ModesComponents.swift`); upgrade to persisted dismissal if reappear-on-launch bothers Chi. [A]

---

## Distribution and v1 scope (decisions recorded 2026-07-05)

Chi's calls (updated 2026-07-05): BOTH channels — direct (notarized + Sparkle) ships first, and a full Mac App Store release targets AUGUST 1 using the RevenueCat SDK + StoreKit IAP in the MAS build. v1 is FREE with paid entitlements ready behind a flag. Cloud transcription INCLUDING realtime is in v1 scope.

SANDBOX SPIKE RESULTS (2026-07-05, sandboxed build with MAS entitlements on this machine): the app launches and runs the full main experience inside the App Sandbox; TCC permissions (microphone, accessibility, screen capture) carry over and report correctly; model detection, CoreML load, and REAL local FluidAudio transcription all succeed in the sandbox (verified transcript via the transcribe-file deep link against seeded container models). Still needing hands-on confirmation sandboxed: hotkey capture with real keypresses, mic dictation end to end, paste into another app, and the system-audio tap. Known MAS-build losses: Sparkle (App Store updates instead), MediaRemote private framework (banned), and AppleScript per-app media pause (Spotify/VLC don't expose scripting access groups) — playback-pause degrades to media-key + volume duck, both already implemented.

- [x] 2026-07-05 MAS TARGET LANDED AND VERIFIED: `TimberVox-AppStore` target (shared sources with the direct target, own scheme) builds with App Sandbox ON, its own entitlements (`TimberVoxAppStore.entitlements`: sandbox, audio-input, network.client, user-selected files — no apple-events, no Sparkle exceptions) and its own `Info-AppStore.plist` (no SU keys). Sparkle is not linked (Frameworks dir empty) and `#if MAS_BUILD` swaps in a stub updater view-model plus an inert `MediaRemoteController` — binary-verified: the direct build contains 4 MRMediaRemote private-symbol strings, the MAS build contains ZERO. The AppleScript pause path stays in code but fails gracefully without the apple-events entitlement, falling back to media key + volume duck. Remaining: Chi's sandboxed hands-on pass (hotkeys, dictation, paste, system-audio tap) on this target. [C]
- [ ] RevenueCat MAS setup: RC project with the App Store app added (App Store Connect API key + shared secret into RC), purchases-ios SDK in the MAS build only, products/offerings mapped to the same "pro" entitlement the worker reads, purchase + restore flows in LicensePane. [B]
- [ ] Work through the two launch checklists: `docs/launch/app-store-launch-checklist.md` and `docs/launch/revenuecat-launch-checklist.md` (compiled 2026-07-05 from Apple's and RevenueCat's official pages, adapted to this project, owner-tagged per item). The RC Test Store API key is stored locally in `Config/RevenueCat.local.xcconfig` (gitignored) for SDK development. [Chi + agent per item tags]
- [ ] Container data migration: MAS build gets a fresh sandbox container — decide whether to import existing direct-build history/settings on first MAS launch (the importer machinery exists). [B]

- [x] 2026-07-05 DEPLOYED: the worker runs at `https://timbervox.peacockery.studio` (custom domain, D1 migrated, all three provider secrets set) and the app defaults to it (`TIMBERVOX_CLOUD_API_URL` still overrides for local dev). Verified live in production: realtime WebSocket session streamed fixture speech to Deepgram with complete finals, and the D1-backed jobs route answers correctly. WARNING: auth/license routes exist, but the deployed workload routes `POST /v1/uploads`, `PUT /v1/uploads/{upload_id}`, `POST /v1/transcriptions`, and `GET /v1/realtime` do not yet call `authenticateCredential`, so cloud ASR is still an open proxy to provider API keys until those routes are gated.
- [ ] Cloud workload auth is the top priority before more production use: require bearer app credentials on upload reservation, upload completion, transcription enqueue, realtime sessions, and usage reads; add app-side Keychain credential provisioning and retry behavior. Existing worker auth/license machinery is present, but it is not enforced on the workload routes yet. [A]
- [ ] Direct-channel payments and entitlement sync: the app holds a generated `app_user_id` and talks only to our worker; RevenueCat Web Billing opens in the browser and returns via `timbervox://`; RC webhooks mirror `app_user_id → pro` into D1 and the worker upgrades the app credential tier. No RevenueCat SDK ships in the direct Developer ID app. [A: webhook + registration + entitlement tests against wrangler dev; C: Chi does one real test purchase]
- [x] 2026-07-05 STEP 1 DONE, wire proven live: `RealtimeTranscriptionClient` in TimberVoxCore (`URLSessionWebSocketTask`, no third-party dependency) with `RealtimeEventParser` covering the worker control envelopes plus raw Deepgram `Results` and Mistral `transcription.*` events, and a float32→linear16 encoder matching the capture engine's output format. Nine unit tests plus an opt-in live integration test (`TIMBERVOX_REALTIME_LIVE=1`) that streamed fixture speech through wrangler dev to real Deepgram and received incremental partials. Realtime route model IDs are provider-prefixed (`deepgram-nova-3`, `mistral-voxtral-mini-transcribe-realtime-2602`).
- [x] 2026-07-05 Realtime step 2 — dictation integration landed: when the selected model has a realtime route (`RealtimeModelRouting`: deepgram IDs map 1:1, voxtral maps to its realtime model), `TranscriptionStore` starts a `RealtimeDictationSession` alongside the recording — the capture engine fans its converted 16k float32 buffers into the WebSocket via an ordered stream, partials publish to `TranscriptionStore.livePartialText`, and on stop the realtime transcript replaces the batch transcribe step. Batch upload of the recorded file remains the automatic fallback when the session yields nothing, and the audio file is always written for history either way. Assembly logic is `RealtimeTranscriptAssembler` (Core) with five unit tests. [Chi verifies: select a cloud model, dictate, confirm faster results; batch path still covers failures]
- [ ] Show `livePartialText` in the recording UI — needs the recording HUD design pass (parked with the HUD redesign; the state is published and ready). [C]
- [x] 2026-07-05 Worker close-flush fixed and verified live: the Durable Object now holds the client socket open until the provider closes (3s cap) after `{"type":"close"}`, so tail finals arrive — the live test that previously lost the utterance ending now receives the complete final transcript.
- [ ] Sparkle updater starts eagerly at launch (`CheckForUpdatesView.swift:36-48`, non-MAS branch), not gated on onboarding completion. Note: `SUEnableAutomaticChecks` is false and the S3 feed bucket does not exist yet (never created in any naming era), so the eager start is currently harmless but the whole update path is dead until the release pipeline lands. [A]
- [ ] Release pipeline: signing environment, notarization, EdDSA-signed update archives, appcast upload to the S3 bucket (`SUFeedURL` already points at it), strictly increasing CFBundleVersion. [B]

---

## Half-built or orphaned

- [x] 2026-07-04: History playback scrubber is real — `HistoryStore` tracks live position (100ms ticker) and duration, `seek(to:)` moves the player, and the detail bar's slider scrubs while playing with a live elapsed label. Chi verifies feel. [C]
- [x] 2026-07-08 supersedes 2026-07-04: Dictionary is not mounted in the sidebar; the earlier sidebar restoration was intentionally undone by the July 8 dead-control cleanup, and the design surface now lives at `Prototype/Panes/PrototypeDictionaryPaneV2.swift`.
- [x] 2026-07-05 (Chi's call): JSON history mirror removed — the GRDB store is the single source of truth. All writes/deletes/trims go through the store; paste-last-transcript and the menubar preview read the newest store record; the JSON file is now read exactly once at startup for the idempotent legacy import.
- [x] 2026-07-05 (Chi's call): AVAudioRecorder fallback deleted — the capture engine is the only microphone backend. If engine startup fails, the recording fails loudly in the log instead of silently degrading. The mic legacy numeric-ID branch stays only as settings migration.
- [ ] `WordRemappingsView` (Features/Transforms) is orphaned — the only word-remapping editor, referenced solely by its own #Preview. Re-home it (Dictionary work). Note: the remap/removal APPLIERS are live in the pipeline and tested (WordRemappingTests, WordRemovalTests); only the editor is unreachable. [B]
- [x] 2026-07-04: Language dropdown derives from the selected voice model's `supportedLanguages` (empty set = unrestricted, which covers the cloud specs that don't declare languages), and switching to a model that lacks the current language resets it to Automatic in the mode-binding setter. Logic lives in `ModeLanguagePolicy` with six unit tests (ModeLanguagePolicyTests, all passing).
- [ ] Extra modes are mock — only the settings-backed Default mode is real. `Mode` model in Core with per-mode overrides resolving against global defaults; global paste-off forces per-mode Auto-paste off. [A]
- [x] 2026-07-04 VERIFIED WIRED: context capture sessions start at recording start (`TranscriptionStore.swift:144`), finish or cancel at stop (:390-392), and the snapshot flows into transcript persistence.

---

## Cloud gaps (worker vs app, verified both sides)

- [ ] Flux: no route exists for it in the worker (zero matches). Add `flux-general-en`/`flux-general-multi` to model-routes, then to the catalog. [A]
- [ ] Batch vocabulary: the worker's batch path sends NEITHER `keywords` nor `keyterm`; the realtime path already supports both (`routes/realtime.ts:40-41,134-135`). Add per-model vocabulary params to batch (Nova-2 `keywords`, Nova-3 `keyterm`). [A]

---

## Reliability ports (from the original Hex repo)

- [x] 2026-07-05: The six reliability commits (plus the three intervening commits they depend on) were ported by final-state behavior, not cherry-picked, because the fork's structure diverged. What landed: `CaptureEngineController` (AVAudioEngine warm capture, 1s ring buffer, 0.45s pre-roll in super-fast mode, channel-0 mapping for multichannel inputs, adaptive 20-80ms stop-grace so endings never clip); the capture engine is now the PRIMARY backend for all recordings with AVAudioRecorder as fallback only; wake/display-wake/device-change/route-change observers with 250ms debounce and deferred rebuilds (never restarts mid-recording; rebuild happens at the next recording start); stale-stop guards (a stop for an old session returns an ignored-stop URL instead of exporting a stale recording.wav); microphone identity persisted by CoreAudio device UID with automatic migration from legacy numeric IDs; session-race rollbacks in the media pause/mute/duck tasks; awaited media restore on stop and cleanup; a "Super fast mode" toggle in Sound → Recording; stop chime now plays AFTER capture finalizes; recording start is cancellable (quick press-release can no longer leave a ghost recording starting); empty transcription results delete their audio; History playback completion is single-fire and ignores stale players; `AudioHardwarePowerHint=None` in Info.plist. Reference sources extracted from the `hex-upstream-2026-07-04` tag.
- [ ] Chi's hands-on pass: dictate across sleep/wake, AirPods connect/disconnect, and device switches; try Super fast mode and confirm instant starts with no clipped first word. [C]
- [ ] Port the upstream race tests as our own (recording-race and playback-race unit tests; upstream's were TCA-specific). [A]
- [ ] Mic menu resilience: show a stable "Unavailable device" entry when the selected mic is missing instead of falling back to the first option (upstream's picker fix; ours is OptionMenu so it needs its own treatment). [B]
- [ ] Microphone failure state made visible and testable. [B]
- [ ] Always-on paste/dump determinism (edge/latch tests). [A]
- [ ] Streaming preview + batch finalization pattern (Nemotron preview, Parakeet final, observable fallback). [B]

---

## Testing gaps (verified: only 2 live suites exist — permission-onboarding, permission-regression)

- [ ] Write the missing live-driver suites (none of these exist today): hotkey-capture, model-download, recording-start-stop, textedit-paste, always-on-lifecycle, post-processing-state, settings-gate. [A]
- [x] 2026-07-04: `SmokeTests` now asserts bundle integrity — languages.json ships and decodes (with the Auto entry), and all six sound-effect assets resolve; this catches the flattened-assets regression class.
- [ ] Unit tests for each dead control as it gets wired (see the dead-controls section). [A]
- [ ] Vocabulary v1 persistence + apply-step tests once the editor is re-homed. [A]

---

## Cleanups

- [ ] Rename `TranscriptionStore+HotKeyInput.swift` (85 lines — the hotkey/push-to-talk input loop) to a self-describing controller. [A]
- [x] 2026-07-04: `TranscriptionStore+Workflow.swift` renamed to `TranscriptionStore+TextTransform.swift` to match its content (the post-transcription text-transform pipeline).
- [ ] Delete preview-only Prototype leftovers when their redesigns land: PrototypeShell.swift (defines preview-only `PrototypeWindow`), PrototypeModeSwitcher, the five recorder variants, PrototypeDictionaryPane v1. [A]
- [ ] Codex audit of the ported UI layer. [A]
- [ ] Periphery dead-code run before release. [A]

---

## Awaiting Chi's hands-on pass (agent-verified code-side, human feel unverified)

- [ ] Shortcut recording in real use (engine + 7 unit tests green).
- [ ] Sound effects audibility/style/volume (wired; labels verified as Default/Classic/Off — the old "rename Simple" item was based on a false premise and is dropped).
- [ ] History and Home on the real store (data wiring tested; look and feel not signed off).

---

## Later (parked)

- Dictionary/Vocabulary UI design pass (Chi). Captions/exports front end (SRT/VTT rendering exists in Core, tested, no UI). Correction loop / enhanced dictionary. Hot mic voice commands (plan doc). Diarization model picker. Recording HUD redesign (docs/recorders/). Error-logging sink decision. Monorepo decision; trigger phrases; license product decision.
