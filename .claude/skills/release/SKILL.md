---
name: release
description: Build and release Cloom entirely from the local machine (no CI costs)
---

# Release

Build Cloom locally, create GitHub Release, update Homebrew tap, and update Sparkle appcast — all from this machine.

## Steps

1. Ask the user which version to release. Suggest the current version from `Info.plist` and offer to bump patch/minor/major.
2. Update `CFBundleShortVersionString` in `CloomApp/Resources/Info.plist` to the chosen version.
3. Update `CFBundleVersion` in `CloomApp/Resources/Info.plist` to the same version (must match for Sparkle).
4. Update `CHANGELOG.md` — add a new section for the version if it doesn't exist, or confirm the existing entry is up to date.
5. Commit `Info.plist` + `CHANGELOG.md` + any other changed files to main.
6. Create git tag `v<version>` and push both main and the tag to remote.
7. Run the local release script:

```bash
./scripts/release.sh <version>
```

This does everything:
1. Builds Rust + Swift
2. Signs app with Developer ID certificate (hardened runtime) using `$APPLE_SIGN_IDENTITY`
3. Creates DMG
4. Notarizes DMG with Apple using `$CLOOM_NOTARIZE_PROFILE` and staples the ticket
5. Signs DMG with Sparkle EdDSA key (from macOS Keychain)
6. Creates GitHub Release with DMG + changelog notes
7. Updates Homebrew tap (`iamsachin/homebrew-cloom`)
8. Updates Sparkle appcast (`appcast.xml` on `gh-pages`)

## Required environment variables (set in `~/.zshrc`)

- `APPLE_SIGN_IDENTITY` — Developer ID Application identity (e.g., `"Developer ID Application: Name (TEAMID)"`)
- `APPLE_DEVELOPER_TEAM_ID` — 10-char Apple Developer Team ID
- `CLOOM_NOTARIZE_PROFILE` — Keychain profile for `notarytool` (created via `xcrun notarytool store-credentials`)

## After the script completes

1. Verify GitHub Release: `gh release view v<version>`
2. Verify appcast: `curl -sL https://iamsachin.github.io/cloom/appcast.xml | head -20`
3. Report a summary table with GitHub Release URL, appcast status, and Homebrew status.

## Build-only mode (no publish)

To build a DMG locally without releasing:

```bash
./scripts/release.sh --build-only
```

## Rules

- Never modify `Secrets.xcconfig` or `Secrets.swift` — the build script handles stubs.
- Do NOT use the Agent or TodoWrite tools.
- If the release fails partway, check what was published (gh release, appcast, homebrew) and either fix forward or clean up:
  - Delete failed release: `gh release delete v<version> --yes`
  - Delete tag: `git tag -d v<version> && git push origin :refs/tags/v<version>`
- CFBundleVersion MUST match CFBundleShortVersionString (semantic version, not a build number) — Sparkle compares these.
