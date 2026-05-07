---
description: End the session with a structured best-practices grade
---

End this session with a structured grade of how well I (Max) applied Anthropic's Claude Code best practices during it. Use the rubric in memory `feedback_session_grading.md`. Reference: https://platform.claude.com/docs/en/best-practices

**Rubric — score each 1–5 with a one-line note + a concrete next-session improvement:**

1. **Verification & success criteria** — Did I provide tests, screenshots, expected outputs, or explicit "fixed looks like X" criteria? Or did I leave you to guess?
2. **Plan vs. execute discipline** — Plan mode used when the task touched multiple files, unfamiliar code, or had ambiguous approach? Skipped when one-sentence-diff trivial?
3. **Prompt specificity & rich context** — Scoped tasks, `@`-references, files/screenshots/symptoms over vague asks? Pointed to existing patterns?
4. **Session hygiene & subagent delegation** — `/clear` between unrelated tasks, course-correct within ~2 attempts, **explicitly asked you to use subagents for broad investigation or verification**, watching context meter, used `/compact` or `/rewind` when warranted?
5. **Failure-pattern avoidance** — Kitchen-sink session, repeat-correction loops, trust-without-verify, unscoped exploration?

**End with an overall takeaway:** the single biggest leverage move for my next session.

**Rules for the review:**
- Cite specific moments from this session as evidence (quote my prompts when useful).
- Be honest — soft-grading defeats the purpose.
- Mark categories N/A if the session genuinely had no opportunity to test them (e.g., no implementation = N/A on verification).
- Keep total review under ~250 words.
