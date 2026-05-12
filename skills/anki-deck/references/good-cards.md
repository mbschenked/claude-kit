# Good card examples

Concrete worked examples from `_source-shan-skills.md`. Each example shows the source line, the extracted card(s), and a one-line rationale. Use these as the shape to match when extracting from a new source.

---

## Example 1 — Definition / rule

**Source (tip 3):**
> Skills are folders, not files — use `references/`, `scripts/`, `examples/` subdirectories for progressive disclosure.

**Card A:**
- **Front:** `Are Claude Code skills files or folders?`
- **Back:** `Folders. The folder contains <code>SKILL.md</code> plus optional <code>references/</code>, <code>scripts/</code>, and <code>examples/</code> subdirectories.`
- **Tags:** `claude-code, skills, structure`

**Card B:**
- **Front:** `Why are skills structured as folders rather than single files?`
- **Back:** `Progressive disclosure — Claude loads <code>SKILL.md</code> by default and only pulls deeper material (references, scripts) when needed, keeping context lean.`
- **Tags:** `claude-code, skills, progressive-disclosure`

**Why these work:** Atomic (one fact each), self-contained (don't reference "tip 3"), and test the *non-obvious* part — a reader unfamiliar with skills wouldn't guess folder + progressive disclosure.

---

## Example 2 — Trigger contract

**Source (tip 5):**
> Skill description field is a trigger, not a summary — write it for the model ("when should I fire?").

**Card:**
- **Front:** `What's the purpose of the <code>description</code> field in a SKILL.md frontmatter?`
- **Back:** `It's a <em>trigger written for the model</em>, not a user-facing summary. Phrase it as &quot;when should I fire?&quot; so Claude knows when to invoke the skill.`
- **Tags:** `claude-code, skills, frontmatter`

**Why it works:** Tests the misconception (people default to writing summaries). Includes the "when should I fire?" mnemonic the source provides.

---

## Example 3 — Anti-pattern as a rule

**Source (tip 7):**
> "Don't railroad Claude in skills — give goals and constraints, not prescriptive step-by-step instructions."

**Card:**
- **Front:** `Should a skill prescribe step-by-step instructions or state goals and constraints?`
- **Back:** `Goals and constraints. Step-by-step "railroading" defeats Claude's ability to adapt to context — give the destination, not the directions.`
- **Tags:** `claude-code, skills, anti-pattern`

**Why it works:** Stem forces the trade-off, body explains the reason. Doesn't just paraphrase — adds the *why*.

---

## Example 4 — Gotcha section

**Source (tip 4):**
> Build a Gotchas section in every skill — highest-signal content, add Claude's failure points over time.

**Card:**
- **Front:** `What's the highest-signal section in a SKILL.md, and what goes in it?`
- **Back:** `The Gotchas section — populated over time with Claude's failure points and edge-case mistakes. It's the section that teaches Claude what to avoid.`
- **Tags:** `claude-code, skills, gotchas`

**Why it works:** Combines two facts (which section + what content) into one atomic answer because they're inseparable conceptually.

---

## Example 5 — Composability rule

**Source (tip 8):**
> Include scripts and libraries in skills so Claude composes rather than reconstructs boilerplate.

**Card:**
- **Front:** `Why include scripts and libraries inside a skill bundle?`
- **Back:** `So Claude <em>composes</em> with the existing code rather than reconstructing boilerplate from scratch each time — faster, more consistent, less prone to drift.`
- **Tags:** `claude-code, skills, composition`

**Why it works:** Tests the underlying principle (composition vs reconstruction), not just the surface practice.

---

## Example 6 — Isolation primitive

**Source (tip 1):**
> Use `context: fork` to run a skill in an isolated subagent — main context only sees the final result, not intermediate tool calls.

**Card:**
- **Front:** `What does <code>context: fork</code> do when set in a SKILL.md?`
- **Back:** `It runs the skill in an isolated subagent. The main context only sees the final result — intermediate tool calls and reasoning stay in the forked context.`
- **Tags:** `claude-code, skills, context-isolation`

**Why it works:** Tests both the mechanism (isolated subagent) and the consequence (main context cleanliness).

---

## Example 7 — Dynamic content primitive

**Source (tip 9):**
> Embed `!command` in `SKILL.md` to inject dynamic shell output into the prompt — Claude runs it on invocation and the model only sees the result.

**Card:**
- **Front:** `What does an embedded <code>!command</code> in a SKILL.md do at invocation time?`
- **Back:** `Claude runs the shell command and substitutes its output into the prompt. The model only sees the result — not the command itself or its execution.`
- **Tags:** `claude-code, skills, dynamic-content`

**Why it works:** Tests the runtime behavior, including the non-obvious detail (model sees output, not command).

---

## Patterns to copy

- **Stem forces the answer.** "Why" / "What" / "Should I X or Y" — never a yes/no question without a follow-up half.
- **Body explains the *reason*, not just the fact.** Repeat the surface rule and Claude is memorizing trivia. Add the why and Claude is testing the concept.
- **Pre-escape `<` `>` `&` inside `<code>` tags.** `<code>references/</code>` would break if the angle brackets weren't preserved as literal text.
- **Hyphenate tags.** `claude-code` not `claude code` (Anki splits tags on whitespace).
- **2 cards from a rich tip is fine.** 4+ cards from one tip is fragmentation — collapse them.
