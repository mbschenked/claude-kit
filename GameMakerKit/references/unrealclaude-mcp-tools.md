---
name: unrealclaude-mcp-tools
description: Catalog of MCP tools exposed by the Natfii/UnrealClaude UE5 plugin (port 3000 on editor launch).
source: https://github.com/Natfii/UnrealClaude
source_sha: 9f12f2edf5484a2da48c675c12a73e4ebe0ae4da
bridge_repo: https://github.com/Natfii/ue5-mcp-bridge
bridge_sha: 2d8d957a6a6c525744ed6c48f8f2d27441dae9c8
fetched: 2026-05-27
audience: agents
status: draft
---

# UnrealClaude MCP tool catalog

UnrealClaude is a UE5 plugin that launches an MCP server (default port 3000) automatically when the Unreal Editor loads; the companion Node.js bridge (`ue5-mcp-bridge`) translates MCP calls into HTTP requests forwarded to the plugin's C++ HTTP handler. The server is reachable at `http://localhost:3000/mcp/status` and exposes 30+ tools across actor manipulation, Blueprint editing, level management, materials, animation, input, assets, scripting, and async task execution. Tools are only available while the editor is running; the server shuts down when the editor closes.

## Tool routing

Two routing patterns exist. Direct tools (read-only ops and simple actor writes) are called by their full `unreal_*` name. Domain-routed tools for complex, stateful operations must be dispatched through the `unreal_ue` router with a `domain:` string parameter; calling the underlying operation name directly on those tools is not supported. From the upstream `CLAUDE.md.default`: "Router-Only Tools MUST use `unreal_ue` domain router." The `tool-router.js` source annotates all domain-routed tools as `destructiveHint=true, idempotentHint=false`; direct tools carry per-tool annotations (see Safety class column below).

## Tools

Tool names with the `unreal_` prefix are direct calls. Rows marked `unreal_ue` in Routing require the `unreal_ue` router with the `domain:` value shown.

| Tool name | Routing | Domain | Purpose | Safety class |
|---|---|---|---|---|
| `unreal_status` | direct | — | Check connection to Unreal Editor | read-only |
| `unreal_get_ue_context` | direct | — | Get UE 5.7 API documentation by category or keyword | read-only |
| `unreal_get_level_actors` | direct | — | List actors in the current level | read-only |
| `unreal_asset_search` | direct | — | Search for assets by class, path, or name | read-only |
| `unreal_asset_dependencies` | direct | — | Get all assets a specific asset depends on | read-only |
| `unreal_asset_referencers` | direct | — | Get all assets that reference a specific asset | read-only |
| `unreal_blueprint_query` | direct | — | Query Blueprint info (list, inspect, get_graph) | read-only |
| `unreal_capture_viewport` | direct | — | Capture screenshot of active viewport | read-only |
| `unreal_get_output_log` | direct | — | Get recent output log entries | read-only |
| `unreal_get_script_history` | direct | — | Get script execution history | read-only |
| `unreal_task_status` | direct | — | Check status of a submitted async task | read-only |
| `unreal_task_result` | direct | — | Get the result of a completed async task | read-only |
| `unreal_task_list` | direct | — | List all async tasks | read-only |
| `unreal_spawn_actor` | direct | — | Spawn actors in the level | per-object-safe |
| `unreal_move_actor` | direct | — | Move/rotate/scale actors | per-object-safe |
| `unreal_set_property` | direct | — | Set properties on actors | per-object-safe |
| `unreal_open_level` | direct | — | Open, create, or list level maps in the editor | sequential-only |
| `unreal_delete_actors` | direct | — | Delete actors from the level | sequential-only |
| `unreal_execute_script` | direct | — | Execute C++, Python, or console scripts | sequential-only |
| `unreal_cleanup_scripts` | direct | — | Remove generated scripts | sequential-only |
| `unreal_run_console_command` | direct | — | Run Unreal console commands | sequential-only |
| `unreal_task_submit` | direct | — | Submit an MCP tool for async background execution | sequential-only |
| `unreal_task_cancel` | direct | — | Cancel a running async task | sequential-only |
| `unreal_ue` | `unreal_ue` | `blueprint` | Modify Blueprints (create, add variables/functions/nodes) | per-object-safe |
| `unreal_ue` | `unreal_ue` | `anim` | Full Animation Blueprint manipulation (states, transitions, conditions) | per-object-safe |
| `unreal_ue` | `unreal_ue` | `character` | Query and modify ACharacter actors; create character config DataAssets | per-object-safe |
| `unreal_ue` | `unreal_ue` | `enhanced_input` | Create/modify InputAction and InputMappingContext assets | per-object-safe |
| `unreal_ue` | `unreal_ue` | `material` | Material instance creation and assignment for Skeletal Meshes | per-object-safe |
| `unreal_ue` | `unreal_ue` | `asset` | Asset create/import/export operations | per-object-safe |

> Note: `unreal_blueprint_query` appears in both the CLAUDE.md.default direct-call list and the router's domain routing table. The direct form supports read queries; write/modify operations require the `blueprint` domain route.

## Concurrency + timeout rules

Verbatim from upstream `CLAUDE.md.default`:

- **Max concurrent tasks in Unreal's queue:** 4
- **Max parallel subagents:** 3 (preserves 1 slot for the lead agent)
- **Timeout chain:** Game thread dispatch = 30 s → Task default = 2 min → Bridge async = 5 min
- **Parallelization by class:**
  - *Read-only (parallel-safe):* `asset_search`, `get_level_actors`, `blueprint_query`, `asset_dependencies`, `asset_referencers`, `capture_viewport`, `get_output_log` — "Call freely in parallel. No conflicts."
  - *Per-object safe:* `spawn_actor`, `move_actor`, `set_property`, `blueprint_modify`, `material`, `character`, `character_data`, `asset`, `enhanced_input`, `anim_blueprint_modify` — parallelize on **different** actors/assets only; never modify the same object from two simultaneous calls.
  - *Sequential only:* `open_level`, `delete_actors`, `execute_script`, `cleanup_scripts`, `run_console_command` — "Must run alone. `open_level` invalidates all refs."
- Bridge async timeout configurable via `MCP_ASYNC_TIMEOUT_MS` env var (default 300000 ms); request timeout via `MCP_REQUEST_TIMEOUT_MS` (default 30000 ms).

## Security guardrails

Verbatim from upstream `CLAUDE.md.default` and C++ plugin layer (bridge itself delegates validation upstream):

- **Path validation:** Block `/Engine/`, `/Script/`, path traversal (`../`)
- **Actor name validation:** Block special characters `<>|&;$(){}[]!*?~`
- **Console command sandboxing:** Block dangerous commands (`quit`, `crash`, `shutdown`)
- **Numeric validation:** Check for NaN, Infinity, and unreasonable bounds on all numeric parameters
- **Script execution:** Disabled auto-approval by default; scripts require a permission dialog confirmation unless `SCRIPT_AUTO_APPROVE=true` is set (audit trail preserved in `LogUnrealClaude`)
- **Engine internals:** Never allow access to engine internals; skip parameter validation is explicitly prohibited by the upstream never-do list

## Asset search parameter names (v1.4.4+)

`unreal_asset_search` renamed its parameters in v1.4.4:

| Old name (deprecated) | New name |
|---|---|
| `asset_type` | `class_filter` |
| `search_term` | `name_pattern` |

Old names still work but emit deprecation warnings. Use new names in all new code.
