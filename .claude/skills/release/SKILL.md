---
name: release
description: Build a release DMG of Cloom (ad-hoc signed, ready to distribute)
---

# Release

Build Cloom for distribution — compiles Rust + Swift, ad-hoc signs, and packages into a DMG.

## Steps

1. Ask the user which version to release. Suggest the current version from `Info.plist` and offer to bump patch/minor/major.
2. Update `CFBundleShortVersionString` in `CloomApp/Resources/Info.plist` to the chosen version.
3. Update `CHANGELOG.md` — add a new section for the version if it doesn't exist, or confirm the existing entry is up to date.
4. Run the release build script:

```bash
./scripts/release.sh <version>
```

5. Report the result:
   - If it succeeds: show the DMG path, file size, and version
   - If it fails: parse the error output and suggest fixes

## After a successful build

Complete the full release flow automatically (don't ask — just do all steps):

### 1. Commit, tag, and push
- Commit `Info.plist` + `CHANGELOG.md` version bump
- Create git tag `v<version>`
- Push main and the tag to remote

### 2. GitHub Release
- Compute SHA256 of the DMG: `shasum -a 256 build/Cloom-<version>.dmg`
- Create a GitHub Release via `gh release create v<version>` with the DMG attached
- Include changelog notes, SHA256, and system requirements (macOS 26+, Apple Silicon) in the release body

### 3. Homebrew Tap
- Clone or pull `iamsachin/homebrew-cloom` to `/tmp/homebrew-cloom`
- Update `Casks/cloom.rb`: set `version` and `sha256` to the new values
- Commit and push to main

### 4. Report
Show a summary table with GitHub Release URL, Homebrew status, and SHA256.

## Rules

- Never modify `Secrets.xcconfig` — the build script handles it.
- Do NOT use the Agent or TodoWrite tools.
