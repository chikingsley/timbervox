# ToyLocal Release Process

This document tracks the current release shape. The app is intended to be a public, signed, notarized macOS app with Sparkle updates and an optional Homebrew cask, but the full one-command release pipeline is not currently present in this checkout.

## Current Local Gates

Install local tooling first:

```bash
bun install
brew install swiftlint
```

Run these before merging releasable changes:

```bash
bun run format:check
bun run lint
bun run test:core
bun run test:app
bun run test:release
```

Or run all of them:

```bash
bun run check
```

## Release Notes

Changesets are used for pending release notes and semver intent:

```bash
bun run changeset:add-ai patch "Fix clipboard timing"
bun run changeset:status
```

For user-facing changes, add a `.changeset/*.md` fragment. The release pipeline should consume these fragments when the signing/notarization tooling is rebuilt.

## Release Artifacts

The intended public artifacts are:

- `ToyLocal-{version}.dmg` for direct download and Sparkle.
- `ToyLocal-{version}.zip` for Homebrew cask distribution.
- `toy-local-latest.dmg` as a stable latest-download object.
- `appcast.xml` for Sparkle updates.

## Existing Release Files

- `bin/generate_appcast`: Sparkle appcast generator binary.
- `toy-local.rb`: Homebrew cask formula template.
- `.changeset/`: pending release-note fragments.
- `CHANGELOG.md`: human-readable release history.
- `ToyLocal/Resources/changelog.md`: in-app changelog content.

## Missing Pipeline Work

Before a real public release, rebuild or restore the release tool that:

1. Applies pending Changesets and updates versions.
2. Builds and archives the app with Developer ID signing.
3. Notarizes the app and DMG.
4. Creates DMG and ZIP artifacts.
5. Generates `appcast.xml` with strictly increasing `CFBundleVersion`.
6. Uploads release artifacts to S3.
7. Creates a GitHub release and updates the Homebrew cask metadata.

Do not publish Sparkle updates manually unless `CFBundleVersion` ordering has been checked. Duplicate or decreasing build numbers break update delivery.
