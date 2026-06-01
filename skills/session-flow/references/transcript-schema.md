# Claude Code transcript JSONL schema (as used by session-flow)

Reverse-engineered from real transcripts under `~/.claude/projects/`. Only the
fields session-flow relies on are documented; transcripts carry many more.

## File layout

```
~/.claude/projects/<encoded-project>/
├── <sessionId>.jsonl                         # main thread (isSidechain:false)
├── <sessionId>/subagents/
│   ├── agent-<agentId>.jsonl                 # one subagent's internal transcript
│   └── agent-<agentId>.meta.json             # {agentType, description, toolUseId}
└── …
```

`<encoded-project>` = the session's cwd with `\`, `/`, and `:` replaced by `-`
(so `D:\ClaudeCode` → `D--ClaudeCode`). Lines in a `.jsonl` are in chronological
(write) order, which is also topological order for the main thread.

## Per-line fields

| Field | Meaning |
|-------|---------|
| `type` | `"user"` \| `"assistant"` \| other (attachments, meta) |
| `uuid` | unique id of this entry |
| `parentUuid` | previous entry's uuid (null at a thread root) |
| `isSidechain` | `true` for subagent-internal lines; main thread is `false` |
| `isMeta`, `isCompactSummary` | internal entries to skip |
| `timestamp` | ISO 8601 |
| `message` | the role payload (see below) |
| `toolUseResult` | on some user entries; `{agentId, …}` links a subagent return |

## Assistant message → `message.content[]` blocks

- `{type:"text", text}` — the agent's visible reasoning/explanation.
- `{type:"thinking", thinking}` — extended thinking (session-flow ignores content).
- `{type:"tool_use", id, name, input}` — a tool call. The ones that matter:
  - **`name:"Agent"` or `name:"Task"`** → subagent spawn.
    `input = {subagent_type, description, prompt}`. The `id` matches the
    `toolUseId` in some `agent-*.meta.json`.
  - **`name:"Skill"`** → `input = {skill}`.
  - any other `name` (Read, Grep, Bash, Edit, …) → a routine tool call; folded
    into a count on the owning decision node, never its own flow node.

## User message → `message.content`

- A plain string, or an array of blocks.
- `{type:"tool_result", tool_use_id, content, is_error}` — a tool/subagent return.
  `tool_use_id` matches the spawning `tool_use.id`.
- A first text block starting with `<command-name>/foo</command-name>` marks a
  **slash command** invocation.
- Text starting with `<task-notification` / `<scheduled-wakeup` /
  `<background-task` is an auto-continuation, not a human prompt — skip it.
- Text starting with `[Request interrupted` marks a user interrupt.

## Subagent meta + transcript

`agent-<id>.meta.json` = `{ "agentType": "...", "description": "...",
"toolUseId": "toolu_..." }`. The `toolUseId` is the authoritative link from a
subagent back to the `Agent`/`Task` tool_use that spawned it — session-flow keys
on this rather than the `toolUseResult.agentId` round-trip. The subagent's own
`.jsonl` is parsed only to count its internal tool usage and grab a tail snippet
of its final assistant text (what it returned).
