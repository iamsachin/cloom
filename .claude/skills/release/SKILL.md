---
name: release
description: Build a release DMG of Cloom (ad-hoc signed, ready to distribute)
---

# Release

Build Cloom for distribution and trigger the full CI-driven release pipeline.

## Steps

1. Ask the user which version to release. Suggest the current version from `Info.plist` and offer to bump patch/minor/major.
2. Update `CFBundleShortVersionString` in `CloomApp/Resources/Info.plist` to the chosen version.
3. Update `CHANGELOG.md` — add a new section for the version if it doesn't exist, or confirm the existing entry is up to date.
4. Commit `Info.plist` + `CHANGELOG.md` version bump to main.
5. Create git tag `v<version>` and push both main and the tag to remote.

## CI handles the rest automatically

Pushing a `v*` tag triggers `.github/workflows/release.yml` which:

1. Builds Rust + Swift, ad-hoc signs, creates DMG
2. Signs DMG with Sparkle EdDSA key (`SPARKLE_ED_PRIVATE_KEY` GitHub secret)
3. Creates GitHub Release with DMG attached (SHA256, install instructions, system requirements)
4. Updates Homebrew tap (`iamsachin/homebrew-cloom`) with new version + SHA256
5. Updates Sparkle appcast (`appcast.xml` on `gh-pages` branch → `https://iamsachin.github.io/cloom/appcast.xml`)

## After pushing the tag

1. Monitor the CI workflow: `gh run list --workflow=release.yml --limit 1`
2. Watch it to completion: `gh run watch <run-id>`
3. If it fails, check logs: `gh run view <run-id> --log-failed | tail -50`
4. Once successful, verify:
   - GitHub Release exists: `gh release view v<version>`
   - Appcast updated: `curl -sL https://iamsachin.github.io/cloom/appcast.xml`
5. Report a summary table with GitHub Release URL, appcast status, and Homebrew status.

## Local-only build (no release)

To build a DMG locally without releasing:

```bash
./scripts/release.sh <version>
```

This builds Rust + Swift, ad-hoc signs, creates DMG, and optionally signs with Sparkle EdDSA (if key is in Keychain).

## Rules

- Never modify `Secrets.xcconfig` or `Secrets.swift` — the build script/CI handles stubs.
- Do NOT use the Agent or TodoWrite tools.
- If CI fails, fix the issue on main and re-tag (delete old tag first, then create + push new one).
- Never create a GitHub Release manually — let CI do it to ensure EdDSA signing and appcast updates.
