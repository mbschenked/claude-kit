#!/usr/bin/env node
/* eslint-disable */
/**
 * extract-flow.mjs
 *
 * Turns a Claude Code session transcript into an ORDERED, BRANCHING flow graph:
 * the main agent's decision points, the subagents it spawned, and the skills /
 * slash-commands it invoked — each with a draft blurb. Emits JSON that the
 * session-flow renderer (assets/template.html) draws as a horizontal flowchart,
 * and that doubles as a project-optimizer evidence sidecar.
 *
 * This reuses the transcript-reading conventions proven in session-report's
 * analyze-sessions.mjs (file discovery, Agent/Skill/slash detection, subagent
 * meta.json resolution) but keeps what session-report throws away: SEQUENCE and
 * BRANCHING. session-report aggregates tokens; we reconstruct control flow.
 *
 * Usage:
 *   node extract-flow.mjs --list [--projects-dir D] [--project NAME]
 *       → JSON array of sessions (id, mtime, turns, preview) for scope selection
 *   node extract-flow.mjs --session <id>[,<id>...] [--projects-dir D] [--project NAME] [--out FILE]
 *       → flow-graph JSON (one session, or multiple as labeled segments)
 *
 * Defaults: --projects-dir = ~/.claude/projects ; --project = encoded $CWD
 * (e.g. D:\ClaudeCode → "D--ClaudeCode").
 *
 * Transcript structure (see references/transcript-schema.md):
 *  - Main thread: <projectDir>/<sessionId>.jsonl, lines in chronological order,
 *    chained by parentUuid, isSidechain:false.
 *  - Subagents:   <projectDir>/<sessionId>/subagents/agent-<id>.jsonl with a
 *    sibling agent-<id>.meta.json = {agentType, description, toolUseId}. The
 *    toolUseId links a subagent back to the Agent/Task tool_use that spawned it.
 *  - Delegation:  assistant content block {type:"tool_use", name:"Agent"|"Task",
 *    input:{subagent_type, description, prompt}}.
 *  - Skill:       {type:"tool_use", name:"Skill", input:{skill}}.
 *  - Slash cmd:   user text containing <command-name>/foo</command-name>.
 *  - Handoff return: user msg with content[].tool_result.tool_use_id === spawn id.
 */

import fs from 'fs'
import os from 'os'
import path from 'path'
import readline from 'readline'

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------
const argv = process.argv.slice(2)
function flag(name, dflt) {
  const i = argv.indexOf(name)
  if (i === -1) return dflt
  const v = argv[i + 1]
  return v === undefined || v.startsWith('--') ? true : v
}
const PROJECTS_DIR = flag('--projects-dir', path.join(os.homedir(), '.claude', 'projects'))
const PROJECT = flag('--project', encodeCwd(process.cwd()))
const LIST = argv.includes('--list')
const OUT = flag('--out', null)
const SESSION_ARG = flag('--session', null)

// Claude Code encodes a project's cwd into a folder name by replacing path
// separators and the drive colon with '-'. D:\ClaudeCode → "D--ClaudeCode".
function encodeCwd(cwd) {
  return cwd.replace(/[\\/:]/g, '-')
}

// Routine tools are folded into a count on their owning decision node rather
// than becoming nodes of their own — that keeps the horizontal flow readable.
// Anything NOT in this set that is a tool_use is still counted but never a node;
// only Agent/Task (subagent) and Skill get their own nodes.
const ROUTINE_TOOLS = new Set([
  'Read', 'Write', 'Edit', 'MultiEdit', 'NotebookEdit', 'Glob', 'Grep', 'LS',
  'Bash', 'PowerShell', 'WebFetch', 'WebSearch', 'ToolSearch', 'TodoWrite',
  'TaskCreate', 'TaskUpdate', 'TaskList', 'TaskGet', 'AskUserQuestion',
  'NotebookRead', 'BashOutput', 'KillShell', 'ExitPlanMode', 'EnterPlanMode',
])

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function projectDir() {
  return path.join(PROJECTS_DIR, PROJECT)
}

function cleanText(s, max = 220) {
  if (!s) return ''
  const t = String(s).replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()
  return t.length > max ? t.slice(0, max - 1) + '…' : t
}

function firstWords(s, n = 8) {
  const t = cleanText(s, 400)
  const words = t.split(' ').slice(0, n).join(' ')
  return words || 'Step'
}

// Read every line of a .jsonl, returning parsed entries in file order (which is
// chronological). Synchronous + line-by-line so huge transcripts stay cheap.
function readJsonl(file) {
  const out = []
  let raw
  try {
    raw = fs.readFileSync(file, 'utf8')
  } catch {
    return out
  }
  for (const line of raw.split(/\r?\n/)) {
    if (!line) continue
    try {
      out.push(JSON.parse(line))
    } catch {
      /* skip malformed line */
    }
  }
  return out
}

// Build toolUseId → {agentType, description, jsonlPath} from the subagents dir.
function loadSubagentMeta(sessionId) {
  const dir = path.join(projectDir(), sessionId, 'subagents')
  const map = new Map()
  let ents
  try {
    ents = fs.readdirSync(dir)
  } catch {
    return map
  }
  for (const name of ents) {
    if (!name.endsWith('.meta.json')) continue
    try {
      const meta = JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8'))
      if (meta && meta.toolUseId) {
        map.set(meta.toolUseId, {
          agentType: meta.agentType || 'subagent',
          description: meta.description || '',
          jsonlPath: path.join(dir, name.replace(/\.meta\.json$/, '.jsonl')),
        })
      }
    } catch {
      /* skip */
    }
  }
  return map
}

// Summarize a subagent's own transcript: how many of each tool it used and a
// tail snippet of its final assistant text (what it concluded / returned).
// NOTE: we deliberately do NOT treat an internal tool_result error (e.g. a
// research subagent hitting a 403 on one WebFetch) as a subagent "failure" —
// those are routine and recoverable, and flagging them produces all-red noise.
// "Produced no final text" is the only signal we trust as a real dead-end.
function summarizeSubagent(jsonlPath) {
  const entries = readJsonl(jsonlPath)
  const toolCounts = {}
  let lastText = ''
  for (const e of entries) {
    const msg = e && e.message
    if (!msg) continue
    if (e.type === 'assistant' && Array.isArray(msg.content)) {
      for (const c of msg.content) {
        if (c && c.type === 'tool_use' && c.name) {
          toolCounts[c.name] = (toolCounts[c.name] || 0) + 1
        }
        if (c && c.type === 'text' && c.text && c.text.trim()) {
          lastText = c.text
        }
      }
    }
  }
  const resultSnippet = cleanText(lastText, 260)
  return { toolCounts, resultSnippet, noResult: resultSnippet.length === 0 }
}

// Detect a real human prompt vs. tool_result / meta / auto-continuation. Mirrors
// session-report's handleUser gating so we don't emit phantom "user" nodes.
function classifyUser(e) {
  if (e.isMeta || e.isCompactSummary || e.isSidechain) return { kind: 'skip' }
  const content = e.message && e.message.content
  let text = null
  if (typeof content === 'string') {
    text = content
  } else if (Array.isArray(content)) {
    const first = content[0]
    if (first && first.type === 'tool_result') return { kind: 'tool_result' }
    if (first && first.type === 'text') text = first.text || ''
  }
  if (text == null) return { kind: 'skip' }
  if (
    text.startsWith('<task-notification') ||
    text.startsWith('<scheduled-wakeup') ||
    text.startsWith('<background-task')
  ) {
    return { kind: 'skip' }
  }
  if (text.startsWith('[Request interrupted')) return { kind: 'interrupt', text }
  const m = /<command-(?:name|message)>\/?([^<]+)<\/command-/.exec(text)
  if (m) return { kind: 'slash', cmd: m[1].trim(), text }
  return { kind: 'human', text }
}

// ---------------------------------------------------------------------------
// Core: build one session's flow graph
// ---------------------------------------------------------------------------
function buildSession(sessionId) {
  const mainFile = path.join(projectDir(), sessionId + '.jsonl')
  if (!fs.existsSync(mainFile)) {
    return { error: `main transcript not found: ${mainFile}` }
  }
  const entries = readJsonl(mainFile)
  const metaByToolUseId = loadSubagentMeta(sessionId)

  const nodes = []
  const edges = []
  let nid = 0
  const nextId = () => `${sessionId.slice(0, 8)}-n${nid++}`

  // currentDecision accumulates assistant text + routine tool counts between
  // handoffs/turns; flushed (committed) just before a handoff or new turn.
  let currentDecision = null
  let lastMainNodeId = null // last node on the MAIN lane (for seq + spawn edges)
  // subagent nodes awaiting a "return" edge to the next main-lane node
  let pendingReturns = []
  const subagentNodeByToolUse = new Map() // tool_use id → node id (for return linking)

  function pushNode(node) {
    node.id = nextId()
    nodes.push(node)
    return node
  }

  function openDecision() {
    if (!currentDecision) {
      currentDecision = { kind: 'decision', lane: 'main', textParts: [], toolCounts: {} }
    }
    return currentDecision
  }

  function flushDecision() {
    if (!currentDecision) return
    const text = currentDecision.textParts.join(' ').trim()
    const tools = currentDecision.toolCounts
    const toolList = Object.keys(tools)
    const node = pushNode({
      kind: 'decision',
      lane: 'main',
      title: text ? firstWords(text, 7) : (toolList.length ? 'Tool work' : 'Thinking'),
      blurb: text
        ? cleanText(text, 220)
        : (toolList.length ? `Ran ${toolList.map(t => `${t}×${tools[t]}`).join(', ')}.` : ''),
      toolCounts: tools,
    })
    linkMain(node.id)
    currentDecision = null
  }

  // Connect a new main-lane node: seq edge from the previous main node, and
  // resolve any pending subagent "return" edges into this node.
  function linkMain(nodeId) {
    if (lastMainNodeId) edges.push({ from: lastMainNodeId, to: nodeId, kind: 'seq' })
    for (const sa of pendingReturns) edges.push({ from: sa, to: nodeId, kind: 'return' })
    pendingReturns = []
    lastMainNodeId = nodeId
  }

  for (const e of entries) {
    if (e.isSidechain) continue // subagent internals live in their own files

    if (e.type === 'user') {
      const c = classifyUser(e)
      if (c.kind === 'human') {
        flushDecision()
        const node = pushNode({
          kind: 'user',
          lane: 'main',
          title: 'User',
          blurb: cleanText(c.text, 240),
        })
        linkMain(node.id)
      } else if (c.kind === 'slash') {
        flushDecision()
        const node = pushNode({
          kind: 'skill',
          lane: 'main',
          via: 'slash',
          skill: c.cmd,
          title: `/${c.cmd}`,
          blurb: `User invoked the /${c.cmd} command.`,
        })
        linkMain(node.id)
      } else if (c.kind === 'interrupt') {
        flushDecision()
        const node = pushNode({
          kind: 'user',
          lane: 'main',
          interrupt: true,
          title: 'Interrupt',
          blurb: cleanText(c.text, 200) || 'User interrupted.',
        })
        linkMain(node.id)
      }
      // tool_result / skip: nothing to emit on the main lane
      continue
    }

    if (e.type === 'assistant') {
      const msg = e.message || {}
      if (!Array.isArray(msg.content)) continue
      for (const block of msg.content) {
        if (!block) continue
        if (block.type === 'text' && block.text && block.text.trim()) {
          openDecision().textParts.push(block.text.trim())
        } else if (block.type === 'tool_use') {
          const name = block.name
          if (name === 'Agent' || name === 'Task') {
            // subagent delegation → flush the decision that led here, then branch
            flushDecision()
            const meta = metaByToolUseId.get(block.id)
            const input = block.input || {}
            const type = (meta && meta.agentType) || input.subagent_type || 'subagent'
            const desc = input.description || (meta && meta.description) || ''
            let detail = { toolCounts: {}, resultSnippet: '', noResult: false }
            if (meta && meta.jsonlPath) detail = summarizeSubagent(meta.jsonlPath)
            const node = pushNode({
              kind: 'subagent',
              lane: 'sub',
              subagent_type: type,
              title: type,
              blurb: cleanText(desc, 160) || `${type} subagent`,
              prompt_head: cleanText(input.prompt, 200),
              toolCounts: detail.toolCounts,
              result_snippet: detail.resultSnippet,
              no_result: detail.noResult,
            })
            subagentNodeByToolUse.set(block.id, node.id)
            // spawn edge from the current main node (the deciding step)
            if (lastMainNodeId) edges.push({ from: lastMainNodeId, to: node.id, kind: 'spawn' })
            pendingReturns.push(node.id)
          } else if (name === 'Skill') {
            flushDecision()
            const sk = (block.input && block.input.skill) || 'skill'
            const node = pushNode({
              kind: 'skill',
              lane: 'main',
              via: 'tool',
              skill: sk,
              title: sk,
              blurb: `Invoked the ${sk} skill.`,
            })
            linkMain(node.id)
          } else if (name) {
            // routine tool → fold into the owning decision node as a count
            const d = openDecision()
            d.toolCounts[name] = (d.toolCounts[name] || 0) + 1
          }
        }
      }
      continue
    }
  }
  flushDecision()

  // ---- summary (project-optimizer evidence sidecar) ----
  const toolTotals = {}
  const subagents = []
  const skills = []
  const slashCommands = []
  const deadEnds = []
  for (const n of nodes) {
    for (const [t, c] of Object.entries(n.toolCounts || {})) {
      toolTotals[t] = (toolTotals[t] || 0) + c
    }
    if (n.kind === 'subagent') {
      subagents.push({
        type: n.subagent_type,
        description: n.blurb,
        toolCounts: n.toolCounts,
        result_snippet: n.result_snippet,
        no_result: n.no_result,
      })
      if (n.no_result) deadEnds.push({ node: n.id, type: n.subagent_type, why: 'subagent returned no final text' })
    } else if (n.kind === 'skill') {
      if (n.via === 'slash') slashCommands.push(n.skill)
      else skills.push(n.skill)
    }
  }

  return {
    session: sessionId,
    project: PROJECT,
    main_file: mainFile,
    generated_at: new Date().toISOString(),
    nodes,
    edges,
    summary: {
      node_count: nodes.length,
      subagents,
      skills,
      slash_commands: slashCommands,
      tool_totals: toolTotals,
      dead_ends: deadEnds,
    },
  }
}

// ---------------------------------------------------------------------------
// List sessions (for the scope-selection step in SKILL.md)
// ---------------------------------------------------------------------------
function listSessions() {
  const dir = projectDir()
  let ents
  try {
    ents = fs.readdirSync(dir, { withFileTypes: true })
  } catch {
    return []
  }
  const out = []
  for (const ent of ents) {
    if (!ent.isFile() || !ent.name.endsWith('.jsonl')) continue
    const id = ent.name.replace(/\.jsonl$/, '')
    const file = path.join(dir, ent.name)
    let mtime = 0
    try {
      mtime = fs.statSync(file).mtimeMs
    } catch {}
    // cheap scan: first human prompt + turn count
    let firstPrompt = ''
    let turns = 0
    let subagentCount = 0
    const subDir = path.join(dir, id, 'subagents')
    try {
      subagentCount = fs.readdirSync(subDir).filter(f => f.endsWith('.jsonl')).length
    } catch {}
    const entries = readJsonl(file)
    for (const e of entries) {
      if (e.type === 'user' && !e.isSidechain) {
        const c = classifyUser(e)
        if (c.kind === 'human') {
          turns++
          if (!firstPrompt) firstPrompt = cleanText(c.text, 100)
        }
      }
    }
    out.push({ id, mtime, mtime_iso: new Date(mtime).toISOString(), turns, subagents: subagentCount, preview: firstPrompt })
  }
  out.sort((a, b) => b.mtime - a.mtime)
  return out
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function pickLatestSession() {
  const list = listSessions()
  return list.length ? list[0].id : null
}

function main() {
  if (LIST) {
    process.stdout.write(JSON.stringify(listSessions(), null, 2) + '\n')
    return
  }

  let sessionIds
  if (SESSION_ARG && SESSION_ARG !== true) {
    sessionIds = String(SESSION_ARG).split(',').map(s => s.trim()).filter(Boolean)
  } else {
    const latest = pickLatestSession()
    if (!latest) {
      process.stderr.write(`No sessions found under ${projectDir()}\n`)
      process.exit(1)
    }
    sessionIds = [latest]
  }

  let result
  if (sessionIds.length === 1) {
    result = buildSession(sessionIds[0])
  } else {
    // multi-session: render as labeled segments along one axis (no cross-session
    // edges). Each session keeps its own node ids (prefixed by session slug).
    const segments = sessionIds.map(buildSession)
    result = {
      project: PROJECT,
      generated_at: new Date().toISOString(),
      multi: true,
      sessions: segments,
    }
  }

  const json = JSON.stringify(result, null, 2)
  if (OUT && OUT !== true) {
    fs.writeFileSync(OUT, json + '\n')
    process.stderr.write(`Wrote ${OUT}\n`)
  } else {
    process.stdout.write(json + '\n')
  }
}

main()
