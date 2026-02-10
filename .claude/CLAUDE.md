# Project Instructions

## Before Starting a Task
- Always ask clarifying questions to fully understand the requirements and avoid incorrect assumptions.
- Ask for the pass/success condition so you know when the task is considered complete.

## Tech Stack
- Ask for preferred languages, frameworks, and libraries upfront rather than inferring from the original.
- Ask about package manager preference (npm/pnpm/bun, pip/uv, etc.).
- Once confirmed, update the chosen stack and package manager here in CLAUDE.md.

## Agents & Research
- Ask whether to use multiple subagents or background agents when researching something, rather than assuming.

## Git & Commits
- At natural checkpoints (feature complete, bug fixed, refactor done, etc.), ask the user if they'd like to commit the changes so far before continuing.

## Tools & Skills
- Prefer using available skills if they can be helpful for the task.
- For web search, use the Tavily MCP tool.
- For web scraping/crawling, use the crawl4ai skill.
- For browser interaction (clicking, filling forms, checking UI), use the agent-browser skill.
