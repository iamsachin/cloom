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

- Tell the user where the DMG is: `build/Cloom-<version>.dmg`
- Ask if they want to commit the version bump and create a git tag (`v<version>`)
- If yes: commit the Info.plist + CHANGELOG.md changes, create an annotated tag, but do NOT push unless asked

## Rules

- Never push tags or commits without explicit confirmation.
- Never modify `Secrets.xcconfig` — the build script handles it.
- Do NOT use the Agent or TodoWrite tools.
