# Temporary Old-to-New Port Map - 2026-07-09

Status: temporary implementation map. This is a planning/audit artifact, not a claim that
the app behavior is finished. It exists because the rebuilt app, old app, chat history,
and model/API work have been moving faster than the boundaries.

## Scope Checked

- Current rebuilt Mac app: `TimberVox/`
- Current Worker API: `TimberVoxAPI/`
- Frozen reference app: `old-app/`
- Rebuild rules: `docs/REBUILD.md`
- API/client boundary notes: `docs/transcription-contract-architecture.md`
- Current native/custom audit: `docs/archive/application-audit-2026-07-09.md`
- Chat history:
  - `home-mac:claude:agent-af4c659652e00cbe6` old-app design inventory.
  - `home-mac:codex:019f4601-6cf4-72e0-bc61-b8464dc9064e` recording indicator follow-up.
  - `home-mac:claude:dc957f5a-4ec4-44a1-81a3-bd139f6e6994` indicator, hot mic, and modes collision notes.
- Apple docs checked for stock/native decisions:
  - SwiftUI Form: https://developer.apple.com/documentation/swiftui/form
  - SwiftUI NavigationSplitView: https://developer.apple.com/documentation/swiftui/navigationsplitview
  - SwiftUI Table: https://developer.apple.com/documentation/swiftui/table
  - SwiftUI searchable: https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app
  - AppKit NSComboBox: https://developer.apple.com/documentation/appkit/nscombobox
  - AppKit NSPanel: https://developer.apple.com/documentation/appkit/nspanel

## Hard Rules

These are already in the repo or recovered from prior work. Treat them as constraints.

1. `old-app/` is a frozen parts bin, not code to bulk-copy.
2. A visible feature should exist only when wired end to end.
3. The Worker owns provider routing, credentials, provider-specific request translation,
   and the public model catalog.
4. The Mac owns recording, settings, UI gating, paste/focus behavior, local workflow, and
   turning user settings into API requests.
5. Mode/model capability decisions should come from `GET /v1/models`; the Mac should not
   maintain a parallel cloud model catalog.
6. Stock SwiftUI/AppKit controls come first. Custom composition is allowed when the stock
   control does not exist or the surface is intentionally visual, but that choice must be
   explicit.
7. History must store raw transcript and transformed transcript when a transform runs.
8. No hidden realtime fallback. If a model does not have a realtime route in the catalog,
   the UI must not show realtime for it.

## Immediate Answers

### `LanguageModelTypes.swift`

This file is currently in the wrong shape for the rebuilt app.

It was copied because `TextTransformPromptBuilder` needs `TextMessage` and
`TextMessageRole`. That part is legitimate. The rest of the file is not a clean
`Core/TextTransform` boundary:

- `LanguageModelProviderID`
- `LanguageModelSpec`
- `TextCompletionRequest`
- `TextCompletion`
- `TextProvider`

Those are old core/provider abstractions. In the rebuilt app, language models come from
`CloudModelCatalogClient` and text completion is executed through
`CloudTextTransformClient`. The next cleanup should split the file:

- Keep `TextMessageRole` and `TextMessage` in `TimberVox/Core/TextTransform/TextMessage.swift`.
- Delete or move the old provider/catalog/request abstractions unless a current caller
  truly needs them.
- Do not leave this file named `LanguageModelTypes.swift` in `Core/TextTransform`.

### `TextTransformOutputNormalizer`

This one is small and justified, but it needs a test.

The old `super` preset explicitly asks the model to wrap output in
`<sw_response_content>` tags. The normalizer strips those tags and trims whitespace before
paste/history. Without it, user-visible output can contain implementation wrapper tags.

It should stay as `TextTransformOutputNormalizer`, but the desired test is simple:

- input: `" <sw_response_content>Hello</sw_response_content> "`
- output: `"Hello"`
- input without tags stays unchanged except outer whitespace.

## Current App Shape

Current rebuilt app files are small enough to name:

- `TimberVox/App/`: app entry and `NavigationSplitView` shell.
- `TimberVox/Core/Cloud/`: batch transcription, realtime transcription, text transform,
  model catalog, HTTP plumbing.
- `TimberVox/Core/Audio/`: microphone recording.
- `TimberVox/Core/Database/`: GRDB transcript store.
- `TimberVox/Core/Paste/`: auto-paste.
- `TimberVox/Core/Stores/ModeStore.swift`: currently too broad; owns mode model,
  persistence, migration, execution planning, text-transform request building, and one
  capability extension.
- `TimberVox/Core/TextTransform/`: copied prompt/context files from old core.
- `TimberVox/Features/Dictation/`: current dictation controller and context capture adapter.
- `TimberVox/Features/Modes/`: current Modes UI; too large and still mixes stock controls,
  custom picker work, and capability interpretation.
- `TimberVox/Features/History/`: current History UI; basic persistence/search/rerun, but
  not yet the old History design.
- `TimberVox/Features/Indicator/`: current passive indicator.
- `TimberVox/Features/Settings/`: cleanest stock-control example in the current app.

Largest current pressure points:

- `TimberVox/Features/Modes/ModesPane.swift`: 618 lines.
- `TimberVox/Features/Dictation/DictationController.swift`: 426 lines.
- `TimberVox/Core/Stores/ModeStore.swift`: 415 lines.
- `TimberVox/Core/TextTransform/DictationContextCapture.swift`: 420 lines.

## Current Worker Shape

The Worker is closer to the right source-of-truth boundary than the Mac UI is.

Important files:

- `TimberVoxAPI/src/routes/models.ts`: publishes `GET /v1/models`.
- `TimberVoxAPI/src/ai/models/types.ts`: public model spec, route spec, transports,
  accepted options, supported languages.
- `TimberVoxAPI/src/ai/models/batch-asr-models.ts`: batch ASR model definitions.
- `TimberVoxAPI/src/ai/models/realtime-asr-models.ts`: realtime ASR model definitions.
- `TimberVoxAPI/src/ai/models/language-models.ts`: language model definitions.
- `TimberVoxAPI/src/ai/models/asr-languages.ts`: model-owned supported-language lists.
- `TimberVoxAPI/src/ai/models/catalog.ts`: merges language, batch ASR, and realtime ASR
  into the public catalog.
- `TimberVoxAPI/src/ai/text-transform.ts`: executes text transform requests.
- `TimberVoxAPI/src/routes/text-transforms.ts`: exposes `POST /v1/text-transforms`.
- `TimberVoxAPI/src/durable-objects/realtime-session.ts`: realtime session boundary.

Do not recreate this catalog in Swift. The Mac should decode it, derive UI state from it,
and submit the selected IDs/options back to the Worker.

## Desired Current Architecture

This is the clean target inside the rebuilt app.

```txt
TimberVox/
  App/
    TimberVoxApp.swift
    AppShellView.swift

  Core/
    Cloud/
      CloudHTTPClient.swift
      CloudBatchTranscriptionClient.swift
      CloudRealtimeTranscriptionClient.swift
      CloudTextTransformClient.swift
      CloudModelCatalogClient.swift
      CloudClients.swift

    Modes/
      DictationMode.swift
      ModeStore.swift
      DictationExecutionPlan.swift
      ModeModelCapabilities.swift

    TextTransform/
      TextMessage.swift
      TextTransformPreset.swift
      TextTransformPromptBuilder.swift
      TextTransformOutputNormalizer.swift
      DictationContext.swift
      DictationContextCapture.swift

    Database/
      TranscriptStore.swift

  Features/
    Dictation/
      DictationController.swift
      DictationWorkflow.swift
      DictationContextProvider.swift

    Modes/
      ModesPane.swift
      ModeListView.swift
      ModeDetailView.swift
      LanguageSelectionControl.swift

    History/
      HistoryPane.swift
      HistoryListView.swift
      HistoryDetailView.swift

    Settings/
      SettingsPane.swift

    Indicator/
      RecordingIndicatorManager.swift
      RecordingPillView.swift
```

The names are not sacred. The boundaries are.

## Old-to-New Inventory

| Old file or area | What it did | Current equivalent | Action |
| --- | --- | --- | --- |
| `old-app/packages/timbervox-core/.../TextGeneration/Prompting/TextTransformPreset.swift` | Owns preset IDs, system prompts, and instructions. | Copied to `TimberVox/Core/TextTransform/TextTransformPreset.swift`. | Keep, then add tests. |
| `.../TextTransformPromptBuilder.swift` | Builds system/user messages from preset, transcript, and context. | Copied to `TimberVox/Core/TextTransform/TextTransformPromptBuilder.swift`. | Keep, then test exact wrapper/context behavior. |
| `.../DictationContext.swift` | Data model for app, focused element, selection, clipboard, vocabulary, system/user context. | Copied to `TimberVox/Core/TextTransform/DictationContext.swift`. | Keep. It is the request-side context contract. |
| `.../DictationContextCapture.swift` | Builder/snapshot structures for incremental context capture. | Copied to `TimberVox/Core/TextTransform/DictationContextCapture.swift`. | Keep only if the rebuilt app uses session capture; otherwise trim after workflow split. |
| `.../TextTransformOutputNormalizer.swift` | Removes Super response tags and trims output. | Copied to `TimberVox/Core/TextTransform/TextTransformOutputNormalizer.swift`. | Keep with tests. |
| `.../Catalog/LanguageModelTypes.swift` | Old language-model provider/catalog/protocol plus text message types. | Copied to `TimberVox/Core/TextTransform/LanguageModelTypes.swift`. | Split. Keep only `TextMessage`/`TextMessageRole`; delete old provider abstractions unless used. |
| `old-app/apps/mac/Sources/Services/DictationContextCaptureService.swift` | Live capture session: app/window/focused element/selection/screen/clipboard/vocabulary. | `TimberVox/Features/Dictation/DictationContextProvider.swift` is a trimmed adapter. | Adapt gradually. Do not bulk-port clipboard/screen monitoring until UI/settings need them. |
| `old-app/apps/mac/Sources/Services/DictationClipboardMonitor.swift` | Clipboard history for during-recording context. | None. | Later, only if clipboard context needs during-recording snapshots. |
| `old-app/apps/mac/Sources/Services/ScreenContextCapture.swift` and `AXVisibleTextCollector.swift` | Screen/AX text collection for richer app context. | Partial direct AX capture in current provider. | Later, permission-gated. Do not add hidden Screen Recording requirement yet. |
| `old-app/apps/mac/Sources/Services/TranscriptionWorkflowService.swift` | Boundary between transcription, text transform, validation, local/cloud paths. | Logic lives in `DictationController`. | Adapt the boundary, not the whole file. Create current `DictationWorkflow`. |
| `old-app/packages/timbervox-core/.../Transcription/Pipeline/*` | Old request/result/validation pipeline. | None direct. | Reference for tests and request shape; do not bulk-port if cloud-only slice is enough. |
| `old-app/packages/timbervox-core/.../Transcripts/TranscriptStore.swift` and `TranscriptRecord.swift` | Rich transcript persistence. | `TimberVox/Core/Database/TranscriptStore.swift`. | Continue adapting. Add context/source app/raw/transformed fields deliberately. |
| `old-app/apps/mac/Sources/Features/History/*` | Polished History list/detail, raw/processed toggle, filters, detail sheet. | `TimberVox/Features/History/HistoryPane.swift`. | Rebuild toward native split/list/detail. Do not copy old custom chrome wholesale. |
| `old-app/apps/mac/Sources/Features/Modes/*` | Polished Modes concept, custom model picker, details, advanced controls. | `TimberVox/Features/Modes/ModesPane.swift`. | Use as design reference only. Current mode contract must be fixed first. |
| `old-app/apps/mac/Sources/Features/Settings/*` | Old settings, shortcuts, sounds, advanced input controls. | `TimberVox/Features/Settings/SettingsPane.swift`. | Port controls only when behavior is live. Current Settings stock style is the preferred baseline. |
| `old-app/apps/mac/Sources/UI/OptionMenu.swift`, `SearchField.swift`, `FloatingLayer.swift` | Custom dropdown/search/popover system. | Current Modes has a custom SwiftUI popover. | Avoid unless stock `Picker`/`Menu` or `NSComboBox` cannot satisfy the UX. |
| `old-app/apps/mac/Sources/UI/Keycap.swift` and shortcut recorder pieces | Old shortcut visuals and recording interaction. | Current uses `KeyboardShortcuts.Recorder`. | Keep native recorder unless custom row behavior is required. |
| `old-app/apps/mac/Sources/Prototype/Recorders/*` | Recording indicator experiments. | `TimberVox/Features/Indicator/*`. | Reference only. The passive indicator is a real feature; target-lock is gone. |
| `old-app/apps/mac/Sources/Features/Transcription/TranscriptionIndicatorView.swift` | Production-grade old capsule visual using Pow. | Current pill/spectrum code. | Reference state/color semantics; do not blindly port Pow dependency. |
| `old-app/apps/mac/Sources/Services/SoundEffectsService.swift` plus audio resources | Start/stop/cancel/sound feedback. | None current. | Later. Port only with Settings controls and resources together. |
| `old-app/apps/mac/Sources/Services/KeyEventMonitorService.swift` plus `HotKeyProcessor.swift` and `HotKey.swift` | CGEvent tap, PTT, hold detection, command keys. | Current only uses `KeyboardShortcuts` for toggle/cancel. | Later for PTT/hot mic. Requires Accessibility and explicit UX. |
| `old-app/docs/hot-mic-voice-commands-plan.md` | Hot mic command-buffer concept. | None current. | Later after realtime workflow is stable. |
| `old-app/apps/mac/Sources/Features/Transforms/WordRemappingsView.swift` and core word-remapping types | Vocabulary/dictionary transforms. | None current. | Later. Do not mix with mode/text-transform cleanup. |
| `old-app/apps/mac/Sources/Features/Models/*` and core model catalog/metrics | Local model library and download UI. | None current except cloud model catalog. | Later for FluidAudio/local models. |
| `old-app/apps/mac/Sources/Stores/*` | Old app-wide store architecture. | Current app has small stores/controllers. | Mine ideas; do not port architecture wholesale. |

## Native-Control Decisions

| Surface | Preferred stock/native choice | Custom allowed when |
| --- | --- | --- |
| App shell | `NavigationSplitView` + `List` | Only for visual shell chrome, not basic navigation. |
| Settings | `Form`, `Section`, `Picker`, `Toggle`, `LabeledContent`, `Button`, `TextField`, `TextEditor` | A row needs custom visuals tied to real behavior. |
| Modes list/detail | Start with `NavigationSplitView` or stock list/detail where possible; use `Form` for detail controls. | The mode card/list interaction is genuinely better as a custom row. |
| Search in panes | `.searchable` on list/table views. | A picker needs inline search; SwiftUI does not provide a stock searchable picker. |
| Searchable picker | `NSComboBox` through `NSViewRepresentable` if stock macOS combo behavior is acceptable. | Use SwiftUI popover only when grouped/custom rows are required. |
| History | `List` or `Table`, `.searchable`, stock detail area. | Audio playback controls and transcript diff/raw toggle need custom layout. |
| Indicator | `NSPanel` plus SwiftUI custom drawing. | This is intentionally visual and floating; stock controls are not the product. |

Important distinction: `HStack` and `VStack` are native SwiftUI APIs, but they are not
stock controls. A dropdown built from stacks, buttons, a text field, and a popover is a
custom control even if every primitive is native.

## Feature Contracts

### Modes

A mode is:

- name
- icon
- audio model public ID from `GET /v1/models`
- transport choice when the selected model supports both batch and realtime
- language code or automatic
- diarization toggle only when the selected route accepts it
- text-transform preset
- text-transform language model public ID
- custom prompt instructions when preset is custom
- context toggles for app, selection, and clipboard context

Modes should not know provider-specific route internals beyond the decoded public catalog.

### Dictation Workflow

The workflow should produce one record:

- raw transcript from ASR
- transformed transcript when text transform runs
- delivered transcript, currently the transformed transcript or raw transcript
- audio URL
- model route/provider metadata
- mode ID/name
- language
- transform preset/model
- context snapshot, once the schema supports it

`DictationController` should own user-triggered state transitions. It should not keep
accumulating cloud route logic, transform assembly, persistence, realtime cleanup, and
paste delivery forever.

### History

History is not just "a list of final strings."

Minimum final contract:

- final text
- raw text, if different
- date/duration/model/provider/language
- audio file path
- mode ID/name
- transform preset/model
- eventually source app/window and context snapshot

UI should show raw vs transformed when both exist.

### Hot Mic

Hot mic is not part of the current cleanup. The recovered intent is:

- long-lived realtime path
- its own accumulated buffer
- Toggle hot mic, Paste buffer, Dump buffer commands
- green standing indicator state
- orange dump moment
- voice commands later, not v1

Do not let hot mic leak into normal dictation until realtime workflow and history are clean.

### Recording Indicator

The target-lock/ring feature is deleted from the product direction. The remaining feature is
a passive indicator that shows recording/transcribing/hot-mic states.

Recovered lessons:

- One shared audio signal should feed visual styles.
- A display floor is okay; it is not an audio/VAD threshold.
- Recording, streaming, processing, hot mic, and captioning are different states.
- If a visual variant is compared against Superwhisper/MacWhisper, use screenshots and
  measured geometry, not memory.

## Exact Implementation Sequence

Do this in order. Do not skip ahead to UI polish while the model/workflow boundary is muddy.

### Phase 0 - Freeze the Map

1. Keep this file as the working map.
2. Do not add more app behavior until the first cleanup phase below is done.
3. When an agent changes this plan, require the changed file list and reason in the commit
   or final response.

### Phase 1 - Clean the Copied Text-Transform Core

1. Add `TimberVox/Core/TextTransform/TextMessage.swift`.
2. Move only `TextMessageRole` and `TextMessage` into it.
3. Delete `TimberVox/Core/TextTransform/LanguageModelTypes.swift`.
4. Verify no current code needs `LanguageModelProviderID`, `LanguageModelSpec`,
   `TextCompletionRequest`, `TextCompletion`, or `TextProvider`.
5. Keep `TextTransformPreset.swift`.
6. Keep `TextTransformPromptBuilder.swift`.
7. Keep `DictationContext.swift`.
8. Keep `TextTransformOutputNormalizer.swift`.
9. Decide whether `DictationContextCapture.swift` is used now. If yes, keep it. If no,
   remove it until session capture is ported.
10. Add tests for preset mapping, prompt builder messages, and output normalizer tags.
11. Build.

### Phase 2 - Split Modes Out of `Core/Stores`

1. Create `TimberVox/Core/Modes/`.
2. Move `DictationMode` into `DictationMode.swift`.
3. Move `DictationExecutionPlan` into `DictationExecutionPlan.swift`.
4. Move `ModeStore` into `ModeStore.swift`.
5. Move model/route UI capability helpers into `ModeModelCapabilities.swift`.
6. Delete `Core/Stores` if it becomes empty.
7. Keep persistence compatible with existing `UserDefaults` keys.
8. Build.

### Phase 3 - Make Capability Interpretation Named

1. Add named properties close to `CloudModelSpec` or in `ModeModelCapabilities`:
   `hasBatchRoute`, `hasRealtimeRoute`, `supportsDiarization`, `acceptsLanguage`,
   `knownLanguageCodes`, `supportsBothBatchAndRealtime`.
2. Make `ModesPane` stop checking raw option strings inline.
3. Language is one field. It renders automatic plus known languages when known.
4. If a route accepts language but has no known list, use a plain text field or defer the
   model until the API has exact languages. Do not invent a second "language support" row.
5. Realtime is one field. Show it only when the selected public model has both routes.
6. Diarization is one field. Show it only when the selected active route accepts it.
7. Build.

### Phase 4 - Extract Dictation Workflow

1. Create `TimberVox/Features/Dictation/DictationWorkflow.swift`.
2. Move "given a plan and recording URL, produce raw/final metadata" out of
   `DictationController`.
3. Keep realtime connection lifecycle either in workflow or a small realtime session owner;
   do not leave all event assembly in the controller.
4. Keep paste delivery in the controller or a tiny delivery service.
5. Store both raw and transformed text.
6. Preserve current no-silent-fallback behavior.
7. Build.

### Phase 5 - Finish Text Transform Through Modes

1. Mode preset `voiceToText` means no text transform request.
2. Every other preset builds messages through `TextTransformPromptBuilder`.
3. Custom preset exposes one custom instructions field.
4. Context toggles are only visible when text transform is enabled.
5. Context capture occurs once per dictation session, not randomly during paste.
6. The normalizer runs only on transform output.
7. Add tests for `DictationMode.textTransformRequest`.
8. Build.

### Phase 6 - Rework Modes UI After Contract Cleanup

1. Keep the current stock `Form` direction.
2. Split `ModesPane` into list/detail/control subviews.
3. Remove duplicate title/name sections.
4. Keep active mode visually explicit.
5. Use a normal `Picker` or `Menu` for small lists.
6. For searchable language/model selection, choose one:
   - `NSComboBox` wrapper for stock macOS search/dropdown behavior.
   - Isolated SwiftUI popover for grouped/favorite/custom rows.
7. Do not show disabled "not available" rows as fake fields.
8. Build.

### Phase 7 - Bring History Up to the Real Contract

1. Add schema columns needed for raw/final/context/source app if still missing.
2. Add a raw/transformed toggle in detail when both exist.
3. Add source app/mode metadata display once data exists.
4. Use `.searchable` for list search.
5. Consider `Table` only if the history surface becomes a dense macOS data browser;
   otherwise keep `List` plus detail.
6. Keep rerun/retranscribe explicit and model-catalog-driven.
7. Build.

### Phase 8 - Settings and Commands

1. Keep Settings stock-form first.
2. Move any duplicated permission polling into one owner only if it keeps growing.
3. Add shortcut rows only when the command exists.
4. For hot mic, add no-default shortcuts only when hot mic runtime exists:
   Toggle hot mic, Paste buffer, Dump buffer.
5. Build.

### Phase 9 - Indicator Cleanup

1. Keep passive `NSPanel`.
2. Ensure panel is non-activating and does not steal focus.
3. Keep `ignoresMouseEvents` unless there is a real control inside it.
4. Keep one shared audio signal for all indicator styles.
5. Record state/color rules in a small testable enum or doc section.
6. Build and visually verify.

### Phase 10 - Later Ports

1. Sound feedback: port service, resources, and settings together.
2. Push-to-talk: port CGEvent tap only when Accessibility UX is ready.
3. Hot mic: use realtime path and explicit buffer semantics.
4. Dictionary/vocabulary: port after modes/history are stable.
5. Local models: port model library and FluidAudio after cloud dictation is clean.

## Verification Gates

For each phase, the minimum gate is:

1. `just generate` if files were added, moved, or deleted.
2. `xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build`
3. Focused tests for touched pure logic.
4. Manual app check only when UI/runtime behavior changed.

Do not report "fixed" from docs-only work. Report it as docs-only.

## Known Current Bad Boundaries

- `ModeStore.swift` should not own type definitions, migration, request building, execution
  planning, and capability helpers in one file.
- `ModesPane.swift` should not inline route/capability interpretation.
- `DictationController.swift` should not keep absorbing realtime, transform, persistence,
  and paste details.
- `LanguageModelTypes.swift` is a wrong copied boundary.
- History persistence is closer, but History UI is still not the old polished contract.
- The current UI can be "native SwiftUI" while still not being a "stock control"; be precise
  about that distinction.

## What Not To Do

- Do not bulk-copy old `Stores/`.
- Do not rebuild a custom dropdown before deciding whether a stock `Picker`, `Menu`, or
  `NSComboBox` is enough.
- Do not put provider-specific ASR rules in `DictationController`.
- Do not create "language support" as a second UI concept. There is one language setting.
- Do not show realtime for models without realtime routes.
- Do not add hot mic commands before the hot mic runtime exists.
- Do not call a planning document an implementation.
