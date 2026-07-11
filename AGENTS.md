# TimberVox working rules

`docs/TODO.md` is the active work list. `docs/REBUILD.md` is the product roadmap. Do not commit unless the user asks.

## Product and architecture

- Port from `old-app/` deliberately; never bulk-copy its architecture.
- A feature lands only when its visible behavior and full runtime path work.
- The Worker catalog is authoritative for cloud models. Every exposed transcription route has an exact supported-language list; models with unknown language support are excluded.
- Dictation means the whole record-to-delivery workflow. Transcription means only speech-to-text.
- `DictationController` owns observable UI state and user commands. Workflow, realtime assembly, persistence, and provider code live outside it.

## Swift consistency

- Run Apple `swift format`; do not run the separate `swiftformat` tool.
- SwiftLint is strict. Do not add a baseline or disable a rule merely to make the gate pass.
- Normalize optional booleans and collections at decoding/framework boundaries. Views consume nonoptional named facts.
- Do not write `== true`, `== false`, or `.isEmpty == false`.
- Capability names use `supports...` consistently. Transport support is derived from route existence; route-specific capabilities are explicit API fields.

## Native-first UI

- Use stock SwiftUI/AppKit controls first: `NavigationSplitView`, `List`, `Form`, `Section`, `Picker`, `Toggle`, `TextField`, `Button`, `Table`, and `.searchable`.
- Custom composition is allowed only when no stock control satisfies the real interaction. Isolate it in a named component and verify it visually.
- AppKit is appropriate for macOS behavior SwiftUI does not supply, such as non-activating panels or a true combo box.

## Required gates

- Run `just format-check`, `just lint`, `just test`, and `just check-build` for Swift changes.
- Run `cd TimberVoxAPI && pnpm run check && pnpm run test:integration` for Worker changes. Mocked contract tests are not accepted as verification.
- Report documentation-only work as documentation-only. A green build does not prove live dictation behavior.
