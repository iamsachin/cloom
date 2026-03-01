---
name: ship
description: Commit changes, create a feature branch, push, and open a PR
---

# Ship

Commit current changes, push to a feature branch, and create a pull request on GitHub.

## Steps

1. Run `git status` (never use `-uall`) and `git diff --stat HEAD` to understand what changed.
2. Read recent commit messages (`git log --oneline -5`) to match the repo's commit style.
3. Analyze all changes and draft a concise commit message (1-2 sentences, focus on "why" not "what"). End with `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`.
4. If already on a feature branch, use it. Otherwise create one from the changes (e.g. `feature/short-description`).
5. Stage relevant files by name (not `git add .`), commit, and push with `-u`.
6. Create a PR via `gh pr create` with:
   - Short title (under 70 chars)
   - Body with `## Summary` (1-3 bullets) and `## Test plan` (checklist)
   - Footer: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
7. Stop local log streaming: `.claude/skills/logs/logs.sh off`
8. Return the PR URL.

## Rules

- Never commit `.env`, credentials, or secrets files — warn if they appear in the diff.
- Never force-push or amend existing commits.
- Always use a HEREDOC for the commit message and PR body to preserve formatting.
- If there are no changes to commit, say so and stop.
- Do NOT use the Agent or TodoWrite tools.
