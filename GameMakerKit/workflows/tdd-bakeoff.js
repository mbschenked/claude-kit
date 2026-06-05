export const meta = {
  name: 'tdd-bakeoff',
  description: 'Generate a TDD of a codebase five ways (ours / Pocock-adapted / hybrid / Pocock-verbatim / technical-writer baseline), score each on 5 axes vs a ground-truth architecture doc, iterate the leaders to >=95%, and return an honest comparison.',
  phases: [
    { title: 'Generate' },
    { title: 'Score' },
    { title: 'Iterate' },
    { title: 'Compare' },
  ],
}

// ---- Config (override via args) ---------------------------------------------
const REPO = (args && args.repo) || '/Users/mbschenk/ClaudeCode/references/TOG-Remake'
const REF  = (args && args.ref)  || `${REPO}/docs/TOG-GAS-Architecture.md`
const KIT  = (args && args.kit)  || '/Users/mbschenk/ClaudeKit/GameMakerKit'
const TARGET = 95          // approval gate
const MAX_ROUNDS = 4       // iteration cap for the leaders

// Unreal scoring weights when a reference doc IS present (must match unreal-design-doc-reviewer)
const WEIGHTS = { 'architecture-fidelity': 35, 'gas-accuracy': 25, 'completeness': 15, 'no-fabrication': 15, 'actionability': 10 }
const AXES = Object.keys(WEIGHTS)

// ---- The five variants ------------------------------------------------------
const VARIANTS = [
  { key: 'A-ours', label: 'ours (kit-native)',
    method: `Read ${KIT}/skills/tdd-generator-ours/SKILL.md AND ${KIT}/skills/tdd-generator-ours/references/unreal-gas-extraction-checklist.md, then execute that skill's method EXACTLY.` },
  { key: 'B-pocock', label: 'Pocock-adapted',
    method: `Read ${KIT}/skills/tdd-generator-pocock/SKILL.md, then execute that skill's method EXACTLY. Keep his PRD-shaped output; do not switch to an architecture-first template.` },
  { key: 'C-hybrid', label: 'hybrid (blend)',
    method: `Read ${KIT}/skills/tdd-generator-hybrid/SKILL.md AND ${KIT}/skills/tdd-generator-hybrid/references/unreal-gas-extraction-checklist.md, then execute that skill's method EXACTLY.` },
  { key: 'D-pocock-verbatim', label: 'Pocock verbatim (control)',
    method: `Read ${KIT}/skills/_vendor/pocock/verbatim/grill-me.SKILL.md and ${KIT}/skills/_vendor/pocock/verbatim/to-prd.SKILL.md and follow them VERBATIM as your instructions: first grill the codebase (resolve every question by reading the code, since there is no human to ask), then synthesize the document using to-prd's PRD template exactly. Do NOT publish anywhere; emit the document as your output. Add nothing from any other method.` },
  { key: 'E-baseline-techwriter', label: 'technical-writer baseline',
    method: `Act as a strong generic technical writer (the kit's technical-writer agent). With no special bake-off method, write the best Technical Design Document you can for this codebase. Read the code to ground it.` },
]

const AXIS_SCHEMA = {
  type: 'object',
  required: ['axis', 'score', 'confidence', 'topGaps'],
  properties: {
    axis: { type: 'string' },
    score: { type: 'number', description: '0-100 for this axis' },
    confidence: { type: 'number', description: '0-100' },
    topGaps: { type: 'array', items: { type: 'string' }, description: 'highest-leverage fixes to raise this axis' },
    note: { type: 'string', description: 'one-line reason for the score' },
  },
}

function overall(axisScores) {
  // axisScores: { axisName: score }. Weighted by WEIGHTS over the axes we have.
  let wsum = 0, acc = 0
  for (const a of AXES) {
    if (typeof axisScores[a] === 'number') { acc += axisScores[a] * WEIGHTS[a]; wsum += WEIGHTS[a] }
  }
  return wsum ? Math.round(acc / wsum) : 0
}

// Fan out the 5 axis reviewers against one draft; return {overall, axes:{}, gaps:[]}
async function score(key, doc, round) {
  const ph = round === 0 ? 'Score' : 'Iterate'
  const results = await parallel(AXES.map(axis => () =>
    agent(
      `You are the unreal-design-doc-reviewer. Read ${KIT}/agents/unreal-design-doc-reviewer.md and adopt its method and critical-by-default stance EXACTLY.\n` +
      `Assigned axis: ${axis} (report ONLY this axis).\n` +
      `Score this GENERATED design document for the Unreal/GAS project at ${REPO}, against the ground-truth reference doc at ${REF}.\n` +
      `Be critical: dock for every issue you can substantiate against the code or the reference; give no benefit of the doubt; never invent criticism.\n\n` +
      `--- GENERATED DOCUMENT (variant ${key}) ---\n${doc}`,
      { label: `score:${key}:${axis}:r${round}`, phase: ph, schema: AXIS_SCHEMA }
    ).then(r => ({ axis, ...r })).catch(() => null)
  ))
  const axes = {}, gaps = []
  for (const r of results.filter(Boolean)) {
    axes[r.axis] = r.score
    for (const g of (r.topGaps || [])) gaps.push(`[${r.axis}] ${g}`)
  }
  return { overall: overall(axes), axes, gaps }
}

// ---- Phase 1: Generate (all five in parallel) -------------------------------
phase('Generate')
const drafts = (await parallel(VARIANTS.map(v => () =>
  agent(
    `${v.method}\n\nTarget codebase root: ${REPO}\nRead real files to ground every claim. Emit the COMPLETE document as your output (markdown). Do not summarize — produce the full document.`,
    { label: `gen:${v.key}`, phase: 'Generate' }
  ).then(doc => ({ key: v.key, label: v.label, doc })).catch(() => null)
))).filter(Boolean)

// ---- Phase 2: Score every draft (initial round) -----------------------------
phase('Score')
const scored = await parallel(drafts.map(d => () =>
  score(d.key, d.doc, 0).then(s => ({ ...d, ...s, round: 0, history: [s.overall] }))
))
scored.sort((a, b) => b.overall - a.overall)
log(`Round 0 scores: ${scored.map(s => `${s.key}=${s.overall}`).join('  ')}`)

// ---- Phase 3: Iterate the leaders (top scorer + hybrid) to >=95% ------------
phase('Iterate')
const leaderKeys = new Set([scored[0].key])
const hybrid = scored.find(s => s.key === 'C-hybrid')
if (hybrid) leaderKeys.add('C-hybrid')

async function iterate(entry) {
  // best-so-far: a failed/empty scoring round must NEVER clobber a good score.
  let best = { overall: entry.overall, doc: entry.doc, axes: entry.axes, gaps: entry.gaps, round: entry.round }
  const history = [...entry.history]
  let round = entry.round
  while (best.overall < TARGET && round < MAX_ROUNDS) {
    round += 1
    const variant = VARIANTS.find(v => v.key === entry.key)
    const revised = await agent(
      `${variant.method}\n\nTarget codebase root: ${REPO}\n` +
      `Below is your PREVIOUS draft (overall ${best.overall}/100) and the prioritized gaps independent critics found against the ground-truth architecture doc. ` +
      `Revise the document to close these gaps — read the code at ${REPO} to verify before asserting; never fabricate. Emit the COMPLETE revised document.\n\n` +
      `--- TOP GAPS ---\n${best.gaps.slice(0, 12).map((g, i) => `${i + 1}. ${g}`).join('\n')}\n\n` +
      `--- PREVIOUS DRAFT ---\n${best.doc}`,
      { label: `revise:${entry.key}:r${round}`, phase: 'Iterate' }
    ).catch(() => null)
    if (!revised) { history.push(null); log(`${entry.key} round ${round}: revise failed — keeping best ${best.overall}`); break }
    const s = await score(entry.key, revised, round)
    // A round where every critic failed → axes empty → overall 0. Treat as a failed round, not a regression.
    if (!s || Object.keys(s.axes).length === 0) { history.push(null); log(`${entry.key} round ${round}: scoring failed — keeping best ${best.overall}`); break }
    history.push(s.overall)
    if (s.overall > best.overall) best = { overall: s.overall, doc: revised, axes: s.axes, gaps: s.gaps, round }
    else best = { ...best, gaps: s.gaps } // adopt fresh gaps even on a non-improving round
    log(`${entry.key} round ${round}: ${s.overall}/100 (best ${best.overall})`)
  }
  return { ...entry, doc: best.doc, overall: best.overall, axes: best.axes, gaps: best.gaps, round, history }
}

const iterated = await parallel(scored.map(s => () => (leaderKeys.has(s.key) ? iterate(s) : Promise.resolve(s))))
iterated.sort((a, b) => b.overall - a.overall)

// ---- Phase 4: Compare (honest) ----------------------------------------------
phase('Compare')
const matrix = iterated.map(s => ({
  variant: s.key,
  label: s.label,
  finalOverall: s.overall,
  scoreHistory: s.history,
  rounds: s.round,
  hit95: s.overall >= TARGET,
  axes: s.axes,
}))

const top = iterated[0]
const spread = top.overall - iterated[iterated.length - 1].overall
const nearTie = (iterated[0].overall - (iterated[1] ? iterated[1].overall : 0)) <= 3

return {
  target: TARGET,
  repo: REPO,
  reference: REF,
  matrix,
  leader: { variant: top.key, overall: top.overall, hit95: top.overall >= TARGET },
  spread,
  nearTie,
  note: nearTie
    ? 'Top variants are within ~3 points — treat as no meaningful fidelity difference; recommend on simplicity/maintainability grounds.'
    : 'Clear leader by fidelity score; see matrix for the margin.',
  // full docs returned so the caller can write them to disk + render
  docs: Object.fromEntries(iterated.map(s => [s.key, s.doc])),
}
