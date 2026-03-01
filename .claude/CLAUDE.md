# Project Instructions

## Before Starting a Task
- Always ask clarifying questions to fully understand the requirements and avoid incorrect assumptions.
- Always use the interactive `AskUserQuestion` tool for questions — never inline questions as plain text in responses.
- Ask for the pass/success condition so you know when the task is considered complete.

## Tech Stack
- Ask for preferred languages, frameworks, and libraries upfront rather than inferring from the original.
- Ask about package manager preference (npm/pnpm/bun, pip/uv, etc.).
- Once confirmed, update the chosen stack and package manager here in CLAUDE.md.

## Agents & Research
- Ask whether to use multiple subagents or background agents when researching something, rather than assuming.

## Code Quality
- Follow the Single Responsibility Principle — each file, class, and function should do one thing well.
- Keep files under ~300 lines and functions under ~30 lines. If a file grows beyond that, split it.
- No file should have more than ~10 public methods. Extract helpers, services, or extensions when it does.
- Prefer composition over large monolithic types — e.g., use extensions (`+Feature.swift`) or dedicated helper types.
- Follow the general architectural design principles of the project — consult plan docs and existing code patterns before introducing new patterns or abstractions.

## Testing
- After every significant change (new feature, refactor, bug fix, architectural change), update existing tests or add new tests to cover the changes.
- Ensure all existing tests still pass after modifications.

## Git & Commits
- At natural checkpoints (feature complete, bug fixed, refactor done, etc.), ask the user if they'd like to commit the changes so far before continuing.

## Plan Docs (`.claude/plans/`)
- Before starting any task, consult the relevant plan files in `.claude/plans/` for context on architecture, data models, module structure, and prior decisions.
- Key files: `00-overview.md` (scope), `01-features.md` (feature matrix), `02-project-structure.md` (file tree), `03-data-models.md` (types), `04-ffi-boundary.md` (Rust FFI), `05-swift-modules.md` / `06-rust-modules.md` (module details), `07-technical-challenges.md` (known issues & solutions), `08-implementation-phases.md` (roadmap).
- After completing a task, update any plan files affected by the changes (new files, renamed types, new features, changed architecture, etc.) to keep them in sync with the codebase.

## Progress Tracking
- After completing each phase, mark it as done in the progress tracker (`.claude/plans/PROGRESS.md`) before moving on.

## Xcode Build & Run
- After rebuilding (Cmd+R), macOS resets TCC permissions for the debug build. Run these before testing:
  ```
  tccutil reset Camera com.cloom.app
  tccutil reset Microphone com.cloom.app
  tccutil reset ScreenCapture com.cloom.app
  ```

## Local Logging
- When starting work on a task, run `.claude/skills/logs/logs.sh on` to stream app logs to `/tmp/cloom-logs/cloom.log`.
- Use `.claude/skills/logs/logs.sh read` to tail logs when diagnosing issues.
- Log streaming is automatically stopped by the `/ship` skill.

## Tools & Skills
- Prefer using available skills if they can be helpful for the task.
- For web search, use the Tavily MCP tool.
- For web scraping/crawling, use the crawl4ai skill.
- For browser interaction (clicking, filling forms, checking UI), use the agent-browser skill.
