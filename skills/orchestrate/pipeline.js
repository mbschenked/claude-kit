export const meta = {
  name: 'orchestrate-pipeline',
  description: 'Implement -> iterative independent review -> fix pipeline for one coding task. Plan, per-slot agents, and effort come from the /orchestrate pre-flight.',
  // NOTE: phase titles must match the phase() calls below. Review/Fix repeat across rounds.
  phases: [
    { title: 'Implement', detail: 'write the code per the grilled, audited plan' },
    { title: 'Review', detail: 'independent axis-specialized reviewers (repeats per round)' },
    { title: 'Fix', detail: 'apply non-minor findings (repeats per round)' },
  ],
}

// ============== EFFORT TIERS  (args.effort: 'quick' | 'balanced' | 'thorough') ==============
const EFFORT = {
  quick:    { lenses: ['correctness'],                            maxRounds: 1 },
  balanced: { lenses: ['correctness', 'requirements', 'quality'], maxRounds: 2 }, // default
  thorough: { lenses: ['correctness', 'requirements', 'quality'], maxRounds: 3 },
}

// ============== DEFAULT AGENTS PER SLOT ==============
// The /orchestrate pre-flight runs /audit-plan (plan-primitive-auditor), which recommends
// the best-fit kit subagent/skill per slot for THIS task. Its picks arrive via args.agents
// and override these defaults. Model tiering: reach for a stronger model on `implement`
// before adding reviewers — model gains beat fan-out gains per token.
const DEFAULTS = {
  implement: { agentType: 'general-purpose',   model: 'sonnet' },
  fix:       { agentType: 'general-purpose',   model: 'sonnet' },
  reviewer:  { agentType: 'code-review-worker', model: 'sonnet' },
}

// One axis per review lens. A reviewer flags ONLY what breaks correctness or a STATED
// requirement — never stylistic preferences or speculative work (the over-engineering trap).
const LENS_AXES = {
  correctness:  'CORRECTNESS: does the code do what the plan says? Runtime hazards, activation/initialization order, boundary cases, null/lifetime. Flag ONLY defects that break correctness.',
  requirements: 'REQUIREMENTS-FIT: does it fully satisfy the task and the approved plan? Flag ONLY unmet STATED requirements or gaps vs the plan.',
  quality:      'QUALITY: reuse of shipped dependencies vs duplication, dead code, naming, scope discipline. Flag ONLY issues that would block a merge — not preferences.',
}

// ---- resolve config from args ----
const task = (args && args.task) ? args.task : (typeof args === 'string' ? args : 'No task provided')
const hasPlan = !!(args && args.plan)
const plan = hasPlan ? args.plan : 'No pre-approved plan supplied.'
const planFraming = hasPlan
  ? 'following the approved plan below — it has been explored, grilled with the user, and audited, so treat its decisions as settled'
  : 'using your own judgment from the task (no pre-grilled plan was supplied — match existing conventions, keep scope tight)'

const tier = EFFORT[(args && args.effort)] || EFFORT.balanced
const maxRounds = tier.maxRounds
const A = (args && args.agents) || {}
const implementSlot = A.implement ? { agentType: A.implement, model: DEFAULTS.implement.model } : DEFAULTS.implement
const fixSlot = A.fix ? { agentType: A.fix, model: DEFAULTS.fix.model } : DEFAULTS.fix
// review lenses: an explicit args.agents.reviewLenses override wins; else build from the effort tier
const lenses = (Array.isArray(A.reviewLenses) && A.reviewLenses.length)
  ? A.reviewLenses.map(l => ({ lens: l.lens, axis: l.axis || LENS_AXES[l.lens] || l.lens, agentType: l.agentType || DEFAULTS.reviewer.agentType, model: l.model || DEFAULTS.reviewer.model }))
  : tier.lenses.map(name => ({ lens: name, axis: LENS_AXES[name] || name, agentType: DEFAULTS.reviewer.agentType, model: DEFAULTS.reviewer.model }))

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['critical', 'important', 'minor'] },
          issue: { type: 'string' },
          evidence: { type: 'string', description: 'Concrete proof: file:line, a code snippet, or the exact plan/spec clause violated' },
          fix: { type: 'string' },
        },
        required: ['severity', 'issue', 'evidence'],
      },
    },
  },
  required: ['findings'],
}

log(`Orchestrating: ${task}  [effort=${(args && args.effort) || 'balanced'}, lenses=${lenses.map(l => l.lens).join('/')}, maxRounds=${maxRounds}, implement=${implementSlot.agentType}]`)

phase('Implement')
const impl = await agent(
  `Implement the task below, ${planFraming}. Write real, idiomatic code matching the codebase's conventions; focused changes only. Do not commit unless asked. Report exactly which files you created/changed and a short summary of each.\n\nTASK:\n${task}\n\nPLAN:\n${plan}`,
  { label: 'implement', phase: 'Implement', agentType: implementSlot.agentType, model: implementSlot.model }
)

// ---- iterative review -> fix loop (evaluator-optimizer), capped at maxRounds ----
let round = 0
let outstanding = []
let converged = false
let reviewFailed = false
const history = []

while (round < maxRounds) {
  round++
  phase('Review')
  const reviews = await parallel(lenses.map(l => () =>
    agent(
      `Independently review the changes just made, through ONE lens only.\nLENS — ${l.axis}\nFind the changed files yourself (\`git diff\` / \`git status\`; if not a git repo, use the implementer's file list). Every finding MUST include concrete evidence (file:line, a snippet, or the violated plan clause). Do NOT raise stylistic preferences or speculative improvements.\n\nTASK:\n${task}\n\nAPPROVED PLAN:\n${plan}\n\nIMPLEMENTER REPORT:\n${impl || 'n/a'}`,
      { label: `review-${l.lens}-r${round}`, phase: 'Review', agentType: l.agentType, model: l.model, schema: FINDINGS_SCHEMA }
    )
  ))
  const valid = reviews.filter(Boolean)
  if (valid.length === 0) {
    // Transient failure: a review round that produced no valid output is NOT clean.
    // (Best-score lesson from tdd-bakeoff: never let an empty round masquerade as a pass.)
    reviewFailed = true
    history.push(`round ${round}: review FAILED (0 valid lenses) — not treated as clean`)
    break
  }
  const nonMinor = valid.flatMap(r => r.findings || []).filter(f => f.severity !== 'minor')
  history.push(`round ${round}: ${valid.length} lens(es) ran, ${nonMinor.length} non-minor finding(s)`)
  if (nonMinor.length === 0) { converged = true; outstanding = []; break }
  outstanding = nonMinor
  phase('Fix')
  const fixList = nonMinor
    .map((f, i) => `${i + 1}. [${f.severity}] ${f.issue}\n   evidence: ${f.evidence || 'n/a'}${f.fix ? '\n   suggested: ' + f.fix : ''}`)
    .join('\n')
  await agent(
    `Apply these review findings to the code for the task below. Make only the changes the findings require; keep them focused and consistent with the codebase and the original implementation intent. Report what you changed per finding.\n\nTASK:\n${task}\n\nIMPLEMENTATION CONTEXT (what was built):\n${impl || 'n/a'}\n\nFINDINGS TO FIX:\n${fixList}`,
    { label: `fix-r${round}`, phase: 'Fix', agentType: fixSlot.agentType, model: fixSlot.model }
  )
  // loop continues -> re-review validates the fix, until clean or maxRounds
}

return {
  task,
  effort: (args && args.effort) || 'balanced',
  agents: { implement: implementSlot.agentType, reviewers: lenses.map(l => `${l.lens}:${l.agentType}`), fix: fixSlot.agentType },
  rounds: round,
  converged,        // true  = a review round came back clean
  reviewFailed,     // true  = a review round produced no valid output (inconclusive, NOT clean)
  outstandingFindings: outstanding.length,
  history,
  implementation: impl,
}
