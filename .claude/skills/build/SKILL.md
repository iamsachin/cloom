---
name: build
description: Build the Cloom Xcode project from the command line to catch compile-time errors
---

# Build Cloom

Build the Cloom macOS app from the command line to catch compile-time errors without switching to Xcode.

## How to build

Run the build script:

```bash
.claude/skills/build/build.sh
```

## After the build

- If it succeeds, report "Build succeeded" with the warning count
- If it fails, parse the errors and report them clearly — show the file, line number, and error message for each
- Suggest fixes for any errors found
- Do NOT attempt to run the app — only build to check for compile errors
