# Flow-graph JSON schema (extract-flow.mjs output)

The renderer (`assets/template.html`) and a future project-optimizer pass both
consume this. Single-session output:

```jsonc
{
  "session": "<sessionId>",
  "project": "<encoded-project>",
  "main_file": "<abs path to the .jsonl>",
  "generated_at": "<ISO>",
  "nodes": [
    {
      "id": "<short-session>-n<seq>",   // unique within the flow
      "kind": "user" | "decision" | "subagent" | "skill",
      "lane": "main" | "sub",            // sub = the subagent branch lane
      "title": "<short label>",
      "blurb": "<one-line description — refine this by hand before rendering>",
      "toolCounts": { "Read": 4, "Grep": 2 },  // routine tools folded in (decision/subagent)

      // user nodes may add:
      "interrupt": true,                 // a [Request interrupted] marker

      // skill nodes add:
      "skill": "skill-creator",
      "via": "tool" | "slash",           // Skill tool call vs. /slash-command

      // subagent nodes add:
      "subagent_type": "Explore",
      "prompt_head": "<first ~200 chars of the prompt it was given>",
      "result_snippet": "<tail of its final returned text>",
      "no_result": false                 // true if it produced no final text (dead-end signal)
    }
  ],
  "edges": [
    { "from": "<id>", "to": "<id>", "kind": "seq" | "spawn" | "return" }
  ],
  "summary": {                           // the project-optimizer evidence block
    "node_count": 15,
    "subagents": [ { "type", "description", "toolCounts", "result_snippet", "no_result" } ],
    "skills": ["skill-creator"],
    "slash_commands": ["commit"],
    "tool_totals": { "Read": 12, "Grep": 5 },
    "dead_ends": [ { "node", "type", "why" } ]
  }
}
```

## Edge kinds

- **seq** — main-lane order: one main node to the next. Drawn gold.
- **spawn** — a main (decision) node to a subagent it launched. Drawn cyan.
- **return** — a subagent back to the next main node after it. Drawn cyan, dashed.

Parallel subagents (spawned in one assistant message) share a `spawn` source and
a `return` target, and the renderer stacks them in one column on the sub lane.

## Multi-session output

```jsonc
{ "project": "...", "generated_at": "...", "multi": true,
  "sessions": [ <single-session object>, … ] }
```

Each session keeps its own node ids (prefixed by its session slug) so there are
no collisions; the renderer draws each as its own labeled horizontal strip.
