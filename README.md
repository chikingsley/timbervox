# TimberVox

TimberVox is a native macOS dictation and transcription application. The current rebuild combines short-form dictation, optional text transformation and context, local transcript history, and authenticated cloud transcription through a Cloudflare Worker.

## Repository

- `TimberVox/` — macOS application
- `TimberVoxTests/` — real persistence integration and gated live acceptance tests
- `TimberVoxAPI/` — Cloudflare Worker
- `old-app/` — frozen reference implementation; evidence to port deliberately, not an architecture to copy
- `docs/TODO.md` — canonical active work
- `docs/REBUILD.md` — product and architecture roadmap
- `CHANGELOG.md` — completed rebuild work and verification

## Development

The Xcode project is generated from `project.yml`.

```sh
just check
just run-app
```

Worker gates:

```sh
cd TimberVoxAPI
pnpm run check
pnpm run test:integration
```

The repository intentionally has no mocked unit-test suite. `just test` runs the real temporary-GRDB integration and compiles the gated acceptance harnesses. The Worker integration test calls the deployed Worker and deployed Cloudflare D1 with the configured development API key; there is no local D1 test database. The gated macOS checks are exposed as `just test-live`, `just test-transform-live`, `just test-pause`, `just test-dual-speech`, `just test-endurance`, `just test-local-matrix-live`, and `just test-local-workflow-live`. They use real devices, permissions, model assets, databases, deployed providers, or human interaction.

The sample-backed connected UI prototype is available only in Debug with `just run-prototype`. It is design evidence, not shipped behavior.
