# timbervox-contracts

Shared, cross-platform API contracts for TimberVox: request/response schemas,
error shapes, sync envelopes, and fixtures shared by every client that talks to
`services/timbervox-api` over HTTP.

This package is language-neutral product surface, **not** Apple-native code
(that lives in `packages/timbervox-core`). Consumers:

- `apps/mac` — validated against these schemas / contract tests
- future `apps/mobile` (Expo/React Native) — imports these TypeScript types
- future `apps/web` — imports these TypeScript types
- `services/timbervox-api` — the server side of the same contract

Do not make any client depend on `packages/timbervox-core` (Swift). Cross-platform
reuse flows through this package; Apple-native reuse flows through the Swift core.
