# Temporary Application Audit - 2026-07-09

Status: temporary working document. This is an audit only. No app behavior, lint config, formatter config, or project configuration is changed by this file.

Scope checked:

- Current macOS app under `TimberVox/`
- Current local lint/format reality
- Old lint/format configs under `old-app/`
- Native SwiftUI/AppKit control choices versus custom SwiftUI composition
- Model/mode/capability ownership boundaries that are causing UI drift

## Vocabulary

This needs to be precise, because "native" has been overloaded.

- Stock control: an off-the-shelf SwiftUI/AppKit control such as `Form`, `Section`, `Picker`, `Toggle`, `TextField`, `Menu`, `Button`, `List`, `Slider`, `LabeledContent`, `ContentUnavailableView`, `NavigationSplitView`, or AppKit controls such as `NSComboBox`.
- Native SwiftUI composition: still native APIs, but assembled manually from primitives like `HStack`, `VStack`, `ZStack`, `ScrollView`, `LazyVStack`, `RoundedRectangle`, `Circle`, `Capsule`, `popover`, custom state, and custom filtering.
- Custom display/animation: visuals intentionally drawn by the app, such as the recording pill, animated spectrum bars, pulsing dots, and non-activating overlay window.

So yes, `HStack` and `VStack` are native SwiftUI APIs. They are not, by themselves, a stock control. If we use them to build a language picker, searchable dropdown, card row, or modal selector, that is custom composition.

Apple docs checked while auditing the control question:

- SwiftUI `searchable` adds a search field to a view/search interface; it is not a searchable dropdown picker by itself. Reference: https://developer.apple.com/documentation/SwiftUI/Adding-a-search-interface-to-your-app
- SwiftUI `popover` presents custom SwiftUI content when state is true. Reference: https://developer.apple.com/documentation/swiftui/view/popover%28ispresented%3Aattachmentanchor%3Aarrowedge%3Acontent%3A%29
- AppKit `NSComboBox` is the closest stock macOS control for "text field plus popup list" behavior. Reference: https://developer.apple.com/documentation/appkit/nscombobox

Conclusion: the current language selector is native SwiftUI composition. It is not a stock picker. If the product rule is "stock/off-the-shelf control first," the options are either a normal `Picker`/`Menu` with no search, or an AppKit-backed `NSComboBox` wrapper if searchable selection is required.

## Files Audited

Current app Swift files:

- `TimberVox/App/AppShellView.swift`
- `TimberVox/App/TimberVoxApp.swift`
- `TimberVox/Core/Accessibility/AccessibilityPermission.swift`
- `TimberVox/Core/Audio/MicrophoneRecorder.swift`
- `TimberVox/Core/Cloud/CloudBatchTranscriptionClient.swift`
- `TimberVox/Core/Cloud/CloudClients.swift`
- `TimberVox/Core/Cloud/CloudHTTPClient.swift`
- `TimberVox/Core/Cloud/CloudModelCatalogClient.swift`
- `TimberVox/Core/Cloud/CloudRealtimeTranscriptionClient.swift`
- `TimberVox/Core/Cloud/CloudTextTransformClient.swift`
- `TimberVox/Core/Database/TranscriptStore.swift`
- `TimberVox/Core/Logging.swift`
- `TimberVox/Core/Paste/PasteService.swift`
- `TimberVox/Core/Stores/ModeStore.swift`
- `TimberVox/Features/Dictation/DictationController.swift`
- `TimberVox/Features/History/HistoryPane.swift`
- `TimberVox/Features/Home/HomePane.swift`
- `TimberVox/Features/Indicator/AudioSpectrumMonitor.swift`
- `TimberVox/Features/Indicator/RecordingIndicatorManager.swift`
- `TimberVox/Features/Indicator/RecordingPillView.swift`
- `TimberVox/Features/Modes/ModesPane.swift`
- `TimberVox/Features/Onboarding/OnboardingView.swift`
- `TimberVox/Features/Settings/SettingsPane.swift`

Largest current Swift files:

- `ModesPane.swift`: 582 lines
- `DictationController.swift`: 419 lines
- `ModeStore.swift`: 411 lines
- `HistoryPane.swift`: 394 lines
- `RecordingPillView.swift`: 205 lines
- `HomePane.swift`: 197 lines
- `OnboardingView.swift`: 195 lines
- `MicrophoneRecorder.swift`: 192 lines
- `CloudModelCatalogClient.swift`: 176 lines
- `SettingsPane.swift`: 143 lines

## Tooling Audit

Commands run:

- `/opt/homebrew/bin/swiftlint lint TimberVox --config old-app/.swiftlint.yml --quiet`
- `/opt/homebrew/bin/swiftlint lint TimberVox --no-cache --quiet`
- `xcrun swift-format lint --configuration old-app/.swift-format --recursive TimberVox`
- `/opt/homebrew/bin/swiftlint rules` filtered for boolean, optional, size, and complexity rules

### Current root config state

There is no active root `.swiftlint.yml` or `.swift-format` in the current app shape. The only configs found are in `old-app/`.

The old SwiftLint config has stale include paths:

- `apps/mac/Sources`
- `packages/timbervox-core/Sources`
- `packages/timbervox-core/Tests`
- `tools/timbervox-cli/Sources`

Because the current app lives in `TimberVox/`, this command returns clean right now:

```sh
/opt/homebrew/bin/swiftlint lint TimberVox --config old-app/.swiftlint.yml --quiet
```

That clean result does not mean the current app is clean. It means the old config is aimed at the old tree.

### What SwiftLint catches today with default config

Default SwiftLint, run directly against `TimberVox/`, catches real issues:

- `TranscriptStore.swift`: `try!` at lines 41, 43, and 72.
- `ModesPane.swift`: type body too large and file too large.
- `DictationController.swift`: type body too large, file too large, one long function.
- `MicrophoneRecorder.swift`: long `start` function.
- `CloudRealtimeTranscriptionClient.swift`: parser complexity.
- `ModeStore.swift`: file too large and long prompt lines.
- `HistoryPane.swift`: type body warning.
- Several noisy default warnings around identifier length, opening braces, and trailing commas.

### What Swift Format catches today

Swift Format catches mechanical style only:

- Ordered import warnings in `DictationController.swift` and `HistoryPane.swift`.
- Indentation warnings in `HistoryPane.swift`.
- Line length in `OnboardingView.swift`.
- Add-line/indentation warnings in `ModeStore.swift`, `CloudModelCatalogClient.swift`, `HomePane.swift`, and `ModesPane.swift`.

It does not catch the product-level problem: "this should have been a stock control instead of a custom popover" or "these capability checks are written three different ways."

### Would lint have caught the boolean/capability discrepancy?

Not reliably.

The current discrepancy in `ModesPane.swift` is:

```swift
selectedModel?.realtimeRoute != nil
selectedRoute?.supportsDiarization == true
selectedRoute?.supportedLanguages?.isEmpty == false
```

SwiftLint has related rules such as `discouraged_optional_boolean`, `discouraged_optional_collection`, `empty_count`, `redundant_nil_coalescing`, `yoda_condition`, and `toggle_bool`. Those are useful, but they do not define our product convention for capability checks.

The actual fix is a code convention and probably a small model/capability layer:

- Views should not inline route/capability interpretation.
- Route/capability checks should be named once, close to `CloudModelSpec` or a dedicated mode-view model.
- Use one style for capability facts:
  - `hasRealtimeRoute`
  - `supportsDiarization`
  - `acceptsLanguage`
  - `hasKnownLanguageList`

Lint can enforce some safety and size boundaries. It will not understand the desired UX/control contract unless we add custom rules or keep the logic out of views.

## UI Surface Audit

### App Shell

File: `TimberVox/App/AppShellView.swift`

Current shape:

- Uses stock `NavigationSplitView`.
- Uses stock `List` for sidebar selection.
- Uses `Label` rows.
- Simple and native-first.

Audit result: good baseline. This is the app-level pattern to preserve.

Risk:

- None major in this file.

### Settings

File: `TimberVox/Features/Settings/SettingsPane.swift`

Current shape:

- Uses stock `Form`, `Section`, `Picker`, `Toggle`, `LabeledContent`, `Button`, and `KeyboardShortcuts.Recorder`.
- `Picker` uses segmented style for appearance and recording indicator style.
- Permission rows use standard `LabeledContent`.

Audit result: this is the cleanest current example of the desired "native-first settings" direction.

Risks:

- It polls permission/login state every second in the view. That works for now, but the same polling pattern also exists in `HomePane` and `OnboardingView`. If this grows, permission observation should move into one shared owner.

### Home

File: `TimberVox/Features/Home/HomePane.swift`

Current shape:

- Mostly stock `Form` and `Section`.
- The main mic button is custom composition: `VStack`, `Button`, `ZStack`, `Circle`, `ProgressView`, and SF Symbol.
- Recent recordings are stock section rows, but the row layout is manual `HStack` composition inside a button.

Audit result: acceptable, but not purely stock. The custom mic button is probably justified because it is the primary action and needs a strong visual state. The rest should stay plain.

Risks:

- Permission polling repeats the Settings pattern.
- The home copy still says focus/paste behavior in broad terms; if target behavior changes, copy should track reality.

### Modes

File: `TimberVox/Features/Modes/ModesPane.swift`

Current shape:

- The detail editor uses stock `Form`, `Section`, `Picker`, `Toggle`, and `Button`.
- The overall pane navigation is custom: `VStack`, custom header, custom list page, manual route enum, custom row cards, and animation.
- The title editor is a plain `TextField` embedded in a custom header.
- The active indicator is a custom green badge.
- The language selector is custom composition: `LabeledContent` plus `Button` plus `popover` plus `TextField` plus `ScrollView` plus `LazyVStack`.
- The mode row is custom card-like composition with `RoundedRectangle` background.

Audit result: this is the main inconsistency hotspot. The file is too large, owns too much UI state, owns capability normalization, and mixes stock controls with custom composition inside one view.

Specific findings:

- Capability booleans are written in different styles at the top of the file.
- The view decides whether a route accepts language using `supportedLanguages`, `acceptedOptions`, and string option names.
- The view normalizes stored mode state after catalog refresh.
- The file contains the main pane, detail page, custom popover, row renderer, icon menu, binding helpers, normalization helpers, labels, and icon choices.

Decision needed:

- If search is not required for languages, use stock `Picker` or `Menu`.
- If search is required and "off-the-shelf native macOS control" is the rule, use an AppKit `NSComboBox` wrapper.
- If the SwiftUI popover stays, treat it honestly as custom composition and move it into a dedicated component such as `SearchableLanguagePicker`.

This file should not keep being the place where every mode rule lands.

### History

File: `TimberVox/Features/History/HistoryPane.swift`

Current shape:

- Uses stock `List`, `Section`, `Menu`, `ToolbarItemGroup`, `Button`, `ContentUnavailableView`, `Form`, `LabeledContent`, and `Slider`.
- Builds the page shell manually with `HStack`, `VStack`, fixed widths, custom search field, manual inspector, and a custom playback bar.

Audit result: mixed. It is less dangerous than Modes because it is not currently driving model capability decisions, but it is still large and visibly formatting-damaged.

Specific findings:

- `List` indentation is currently wrong around the day groups.
- Search field is custom `HStack` + `TextField` + rounded background instead of `.searchable`.
- Detail view and playback bar live in the same file.
- Toolbar menus are reasonable stock controls.

Likely direction:

- Run Swift Format when formatter adoption is allowed.
- Split `TranscriptDetailView` and `PlaybackBar`.
- Consider `.searchable` on the appropriate container if the search field should be stock SwiftUI search rather than custom inline search.

### Onboarding

File: `TimberVox/Features/Onboarding/OnboardingView.swift`

Current shape:

- A custom first-run flow built with `VStack`, `HStack`, `Group`, `Image`, `Text`, `Label`, and `Button`.
- Uses custom page dots and custom keycap styling.

Audit result: custom composition is expected here. Onboarding is not a settings form. It can be more composed than Settings or Modes, as long as it stays small and boring.

Risks:

- It has repeated permission polling.
- It has a long line that Swift Format/SwiftLint flag.

### Recording Indicator

Files:

- `TimberVox/Features/Indicator/RecordingIndicatorManager.swift`
- `TimberVox/Features/Indicator/RecordingPillView.swift`
- `TimberVox/Features/Indicator/AudioSpectrumMonitor.swift`

Current shape:

- The overlay window uses an AppKit `NSPanel` with `.nonactivatingPanel`, `.borderless`, and `ignoresMouseEvents = true`.
- The pill is intentionally custom drawing and animation.
- The spectrum monitor uses Accelerate and publishes bar values.

Audit result: this is the right place for custom UI. A recording indicator is not a settings row or picker. The important rule is isolation: keep this custom work contained here and do not let its patterns leak into Settings/Modes.

Risks:

- Hard-coded colors and sizes live inside `RecordingPillView`.
- `AudioSpectrumMonitor` logs every computed frame. That may be too noisy for normal runs.
- The overlay position is currently bottom-center only. If overlay position returns as a feature, it should be a small explicit setting, not target-lock behavior.

### Menu Bar

File: `TimberVox/App/TimberVoxApp.swift`

Current shape:

- Uses stock `Window`, `MenuBarExtra`, `Button`, `Text`, and `Divider`.
- Menu state follows dictation state.

Audit result: fine.

Risk:

- None major.

## Non-UI Ownership Audit

### Cloud Model Catalog

File: `TimberVox/Core/Cloud/CloudModelCatalogClient.swift`

Current shape:

- `CloudModelSpec` decodes model metadata.
- `CloudModelRoutes` separates batch and realtime.
- `CloudModelSpec.batchRoute` and `CloudModelSpec.realtimeRoute` derive route specs.
- `CloudModelCatalogStore` exposes filtered lists: batch transcription models, realtime transcription models, audio transcription models, and language models.

Audit result: this is the right direction. The catalog already knows enough for the UI not to guess.

Risk:

- Some capability interpretation still lives outside the catalog, especially diarization and language acceptance.
- `CloudModelRouteSpec.supportsDiarization` is currently an extension in `ModeStore.swift`, which makes ownership hard to see.

### Mode Store

File: `TimberVox/Core/Stores/ModeStore.swift`

Current shape:

- Stores language labels.
- Stores text transform presets and their prompt strings.
- Stores `DictationMode`.
- Stores `DictationExecutionPlan`.
- Owns mode persistence in `UserDefaults`.
- Builds execution plans from the cloud catalog.
- Builds text transform requests from a mode.
- Adds `CloudModelRouteSpec.supportsDiarization` as an extension.

Audit result: too much is in one file. It mixes data model, persistence, presentation labels, prompt content, cloud request construction, and route capability interpretation.

Specific concern:

- `ModeLanguageOption` and `ModeLanguageLabel` are UI/presentation-adjacent, but live in `Core/Stores`.
- `ModeTextTransformPreset` owns long prompt strings in the same file as persistence.
- `DictationMode.textTransformRequest` couples mode storage to the cloud text-transform API.
- `CloudModelRouteSpec.supportsDiarization` should live near the cloud model route type or in a dedicated capabilities helper.

### Dictation Controller

File: `TimberVox/Features/Dictation/DictationController.swift`

Current shape:

- Owns keyboard shortcut registration.
- Owns dictation state.
- Owns microphone recording lifecycle.
- Owns execution-plan lookup.
- Owns realtime connection lifecycle.
- Owns batch transcription call.
- Owns text transform.
- Owns transcript persistence.
- Owns paste/clipboard delivery.
- Owns last-transcript state for UI.

Audit result: it works as an MVP coordinator, but it is now large enough that every feature risks landing here. SwiftLint catches this as a type body length problem.

Likely direction:

- Keep `DictationController` as UI-observable state coordinator.
- Move execution into a `DictationWorkflow` or `TranscriptionWorkflow` object.
- Keep raw transcript and transformed transcript as first-class outputs.
- Keep realtime assembly separate from the controller.

### Transcript Store

File: `TimberVox/Core/Database/TranscriptStore.swift`

Current shape:

- GRDB-backed transcript persistence.
- Migrates v1, v2 metadata, and v3 raw text/modes.
- Stores both `text` and `rawText`.

Audit result: good functionality, but unsafe initialization.

Specific finding:

- `try!` is used for app support directory creation, database queue creation, and migration. SwiftLint catches this as errors.

Likely direction:

- Replace forced initialization with a throwing initializer or a stored initialization error that the UI can surface.

### Realtime Client

File: `TimberVox/Core/Cloud/CloudRealtimeTranscriptionClient.swift`

Current shape:

- Actor wraps `URLSessionWebSocketTask`.
- Sends PCM.
- Parses multiple event families: app events, Deepgram `Results`, text deltas, segment/done, and errors.

Audit result: reasonable boundary, but parser is complex and provider-specific enough to split.

Specific finding:

- SwiftLint default reports cyclomatic complexity in the parser.

Likely direction:

- Split `RealtimeEventParser`.
- Keep provider event parsing testable outside the WebSocket actor.

## Main Consistency Problems

1. Modes is not native-first in the same sense as Settings.

Settings is mostly stock controls. Modes has a custom shell, custom header, custom rows, custom language popover, capability interpretation, and normalization logic in one view.

2. Capability checks are not owned in one place.

The catalog has route data, but Modes still asks questions like "does this route support realtime/diarization/language" inline. That is how the UI starts showing duplicate or contradictory state.

3. The language selector decision is unresolved.

Current implementation is a SwiftUI popover. That can be okay, but it is not a stock picker. If "native/off-the-shelf" means no custom picker behavior, use `Picker`/`Menu` or AppKit `NSComboBox`.

4. Mode storage and mode presentation are mixed.

`ModeStore.swift` contains storage, labels, prompts, cloud request construction, and capability extension code.

5. Dictation workflow is concentrated in one controller.

The controller knows too much about audio, realtime, batch, transform, persistence, and paste.

6. Formatter/linter configs exist only as old-app references.

The old configs are useful, but not currently wired to the rebuilt app.

## What Lint/Format Should Eventually Do

Do not add this yet unless the team decides to. This is only the audit recommendation.

Bring forward Swift Format first for mechanical consistency:

- Ordered imports
- Indentation
- Line breaks
- Line length according to chosen config

Bring forward SwiftLint after updating paths:

- Include `TimberVox`
- Exclude `.build`, `.build/DerivedData`, `old-app`, `TimberVoxAPI/node_modules`, and Xcode generated paths
- Keep crash-risk rules as errors:
  - `force_try`
  - `force_cast`
  - `force_unwrapping`
  - `implicitly_unwrapped_optional`
- Keep size and complexity warnings, but tune thresholds for this small app.

What lint/format will catch:

- `try!`
- Huge files/types/functions
- Parser complexity
- Import ordering
- Bad indentation
- Long lines
- Some optional/collection style smells if opt-in rules are enabled

What lint/format will not catch:

- Whether a picker should be stock or custom
- Whether a custom popover is acceptable UX
- Whether capability rows should be hidden, disabled, or shown as status
- Whether model capability logic belongs in a view
- Whether a language list belongs in the API catalog or local UI
- Whether "native" means stock control or native composition

## Recommended Code Policy

Policy for controls:

- Use stock SwiftUI/AppKit controls by default in Settings, Modes, and History.
- Custom composition is allowed only when a stock control cannot do the job and the component is named and isolated.
- Do not build picker-like controls inline inside a pane.
- Do not put card-like custom rows inside settings forms unless the whole surface is intentionally custom.

Policy for capabilities:

- Catalog route data is the source of truth.
- The UI may ask named questions only, not inspect route internals.
- Good view-facing names:
  - `canStreamRealtime`
  - `supportsDiarization`
  - `acceptsLanguage`
  - `hasKnownLanguageList`
- Unsupported feature controls should usually be absent, not duplicated as a second "not available" row.
- If a feature is shown but unavailable, it needs a single disabled control with a clear reason, not multiple separate status rows.

Policy for Modes specifically:

- Modes should have an active mode list and one detail editor.
- The detail editor should be stock `Form` controls wherever possible.
- The mode title/icon header can be custom, but should be a small component.
- Language selection must be one explicit decision:
  - Stock `Picker`/`Menu` without search
  - AppKit `NSComboBox` wrapper for native searchable combo behavior
  - Custom SwiftUI `SearchableLanguagePicker` component, acknowledged as custom

## Recommended Refactor Order

1. Decide the language selector policy.

This blocks whether `languagePopoverControl` is kept, moved, or replaced.

2. Move capability interpretation out of `ModesPane`.

Put route capability helpers near `CloudModelRouteSpec` or in a small `ModeCapabilities` type.

3. Split `ModesPane`.

Suggested split:

- `ModesPane.swift`: routing only
- `ModeDetailForm.swift`: form fields
- `ModeHeader.swift`: title/icon/active state
- `ModeRow.swift`: list row
- `SearchableLanguagePicker.swift` or `ModeLanguagePicker.swift`: depending on selector policy

4. Split `ModeStore.swift`.

Suggested split:

- `DictationMode.swift`
- `ModeStore.swift`
- `ModeTextTransformPreset.swift`
- `ModeLanguageLabel.swift`
- `DictationExecutionPlan.swift`
- Route capability helpers near the cloud model types

5. Split dictation workflow from UI state.

Keep `DictationController` observable, but move the batch/realtime/transform/persist/deliver sequence into a workflow object.

6. Fix `TranscriptStore` forced initialization.

This is a real SwiftLint error and a real crash boundary.

7. Format History and split detail/playback views.

This is lower risk than Modes, but the file is already too large and visibly malformed.

8. Only after the above, add lint/format configs.

Adding lint first will create noise. The better order is to use this audit to clean the worst shape problems, then turn the tools on with current paths.

## Current Answer To The Confusing Part

The concern is valid.

We are using native APIs, but not always stock controls. In Modes, the current code has effectively built a custom searchable language picker with SwiftUI pieces. That is not "wrong" at the API level, but it violates the simpler native-first direction unless we explicitly decide that this component is worth custom composition.

The clean path is not "ban HStack/VStack." That would be impossible in SwiftUI. The clean path is:

- Stock controls for normal settings and mode fields.
- Named, isolated custom components only where stock controls do not cover the interaction.
- Capability logic owned outside the view.
- Formatter/linter added later after the shape is sane.
