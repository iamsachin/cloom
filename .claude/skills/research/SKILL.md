---
name: research
description: Research a topic in parallel using multiple subagents with different approaches
---

# Parallel Research

Launch multiple subagents in parallel to research a topic from different angles, then synthesize the results.

## How to use

The user will provide a research question or topic. Parse it and decide on 2-4 distinct research angles.

## Steps

1. **Identify angles**: Break the topic into 2-4 independent research approaches. Examples:
   - Different search queries or keywords
   - Codebase exploration vs. web search vs. documentation lookup
   - Different files, modules, or layers of the stack
   - Competing libraries, patterns, or solutions

2. **Launch agents in parallel**: Use the Agent tool to spawn all research agents in a **single message** (this is critical for true parallelism). Each agent should:
   - Have a clear, specific prompt describing what to find
   - Use `subagent_type: "Explore"` for codebase research, or `subagent_type: "general-purpose"` for web/docs research
   - Be named descriptively (e.g., "Research Redux approach", "Search codebase for auth patterns")

3. **Synthesize**: Once all agents return, combine their findings into a clear summary:
   - What each angle discovered
   - Where approaches agree or conflict
   - A recommendation or next steps if the user asked for one
   - Key file paths, URLs, or code snippets found

## Rules

- Always launch agents in a **single message** for true parallelism — never sequentially.
- Keep each agent's prompt focused on one angle — don't give a single agent the whole question.
- Default to 3 agents unless the topic clearly needs fewer or more.
- Prefer `model: "haiku"` for simple search tasks to minimize cost. Use `"sonnet"` for tasks needing deeper analysis.
- Summarize the results yourself — don't ask the user to read raw agent output.
