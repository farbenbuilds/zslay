# Repository Guidelines

## Project Structure & Module Organization

The public Zig API starts in `src/root.zig`. Keep protocol types and layouts in `src/types.zig`, pure header and masking operations in `src/frame.zig`, caller-backed collections in `src/queue.zig`, connection state in `src/event.zig`, and C ABI exports in `src/c_api.zig`. Tests live in `src/test.zig`; the README banner is under `misc/`. Build configuration is in `build.zig`, `build.zig.zon`, and `flake.nix`. See `CODEBASE.md` for the full file map.

Core code must remain zero-allocation and I/O-agnostic. Use caller-provided buffers, flat data layouts, static dispatch, and explicit integer-backed FFI types. Do not add socket operations or heap allocators to parser paths.

## Functional Core

`src/frame.zig` must stay pure: given the same input it returns the same output and writes only into caller-owned buffers. All mutation lives in `src/queue.zig` and `src/event.Conn`, reached exclusively through caller-provided context pointers. Use flat iterative loops with early returns; recursion, dynamic dispatch, and silent fallbacks are prohibited. Invalid input returns a typed error instead of a substituted default.

## Sub-Agent Directory

`.opencode/agents/`, `.codex/agents/`, and `.agents/agents/` provide matching specialized agents for parser, event-loop, C ABI, Node-API, tests, review, release, and docs work. All three provide an `architect` → `developer` → `reviewer` → `integrator` team procedure; agy names the roles `zslay-architect`, `zslay-developer`, `zslay-reviewer`, and `zslay-integrator`. Read `AGENT_DIRECTORY.md` for the roster, ownership map, workflow, and skill coverage. Each agent follows its listed skills and repository checks. Keep one owner per pull request scope and hand cross-scope work to the owning specialist. Claude Code loads `CLAUDE.md`, which imports this file; treat both files as one rule set.

## Optional Herdr Orchestration

[Herdr](https://herdr.dev) is an optional terminal workspace for running multiple coding agents side by side. Use it only when the user explicitly asks to use Herdr, `herdr` is installed, and `HERDR_ENV=1` is set in an active Herdr session. If Herdr was requested but the environment check fails, report the problem and stop; do not silently switch to another orchestration mode. If Herdr was not requested, ignore this section and execute tasks directly through the repository sub-agents. Herdr supplies panes; it does not replace the ownership rules in `AGENT_DIRECTORY.md`.

Any agent kind supported by `herdr agent start --help` (for example `opencode`, `claude`, `codex`, or `agy`) can act as the orchestrator or a worker. OpenCode and Codex workers load their project roles from `.opencode/agents/` and `.codex/agents/`; agy workers load `.agents/agents/`; other kinds must be given the role, scope, and rules in the prompt.

### Roles and loop prevention

- The orchestrator owns the plan, pane layout, task prompts, and final coordination. Reviewer and integrator stages remain as defined in `AGENT_DIRECTORY.md`.
- Leaf workers execute the assigned task and do not delegate further. Coordinator roles may hand off within the architect → developer → reviewer → integrator procedure; never spawn an unrequested second layer of workers.
- Keep one owner per pull request scope. Never assign two workers to edit the same file concurrently.
- Workers follow this file and `AGENT_DIRECTORY.md`, including the rule that no agent commits, pushes, tags, or opens a pull request unless the user explicitly asked.

### Orchestrator workflow

1. Confirm the request and the session, then learn the installed CLI. The binary is authoritative for syntax:

   ```bash
   test "${HERDR_ENV:-}" = 1
   herdr --help
   herdr agent
   herdr agent list
   herdr pane list
   ```

2. Split a sibling worker pane in the current directory without moving the user's focus. Read the new pane ID from `.result.pane.pane_id` in the JSON response:

   ```bash
   herdr pane split --current --direction right --cwd "$PWD" --no-focus
   ```

3. Start the worker with a unique name and the requested kind. Pass native arguments after `--`. For an OpenCode worker, pass `--auto`, then select the matching team role with `/agents` or an `@team/<role>` prompt mention; the interactive `opencode` command in the installed 2.3.0 CLI does not accept `--agent`. Use `opencode2 run --agent team/<role> --auto` only for non-interactive runs. For an agy worker, select the project role directly with `--agent` and add `--mode auto` for unattended worker panes:

   ```bash
   herdr agent start reviewer --kind opencode --pane <pane-id> -- --auto
   herdr agent start parser --kind agy --pane <pane-id> -- --agent zslay-parser --mode auto
   ```

   Herdr starts the `opencode` executable, not `opencode2`; keep `opencode` on `PATH` pointed at the v2 binary you intend. The OpenCode team roles are `team/architect`, `team/developer`, `team/reviewer`, and `team/integrator` under `.opencode/agents/team/`. The agy roles are `zslay-architect`, `zslay-developer`, `zslay-reviewer`, and `zslay-integrator` under `.agents/agents/`.

4. Send a self-contained prompt. Worker panes do not see the orchestrator transcript, so include the scope boundary, exact paths, expected behavior, acceptance criteria, and verification commands:

   ```bash
   herdr agent prompt reviewer "In src/frame.zig ... Run zig build test. Do not edit files outside this scope." --wait --timeout 120000
   ```

5. Monitor until the worker settles. `agent prompt --wait` returns on `idle`, `done`, or `blocked`, and can fail with `agent_prompt_stalled` or `timeout`. A stalled or timed-out response does not prove the prompt was not delivered; inspect `agent get` and `agent read` before retrying. If a worker is `blocked`, show the approval request to the user instead of answering it yourself. `--auto` only auto-approves actions that are not explicitly denied, so denied actions and interactive prompts still surface as `blocked`:

   ```bash
   herdr agent list
   herdr agent read reviewer --source recent-unwrapped --lines 120
   ```

6. Review the result with `git status` and `git diff`, run the checks in this file, and hand cross-scope findings to the owning agent. Do not close panes or stop the Herdr server unless the user asked.

## Skills

Shared project skills live in `.agents/skills/` and are locked by `skills-lock.json`. Platform copies from the graphify installer live in `.opencode/skills/graphify/` and `.codex/skills/graphify/` and are version-stamped by `.graphify_version`. `SKILL.md` is the human-readable catalog; `AGENT_DIRECTORY.md` is the source of truth for agent-to-skill coverage.

- Zig work uses `zig-0-17`, `zig-best-practices`, `zig-testing`, and `zig-tiger-style`. The repository pins Zig 0.17.1 in `flake.nix` and `build.zig.zon`; apply the 0.17 guidance directly. Use TigerStyle for safety ideas such as entry assertions, bounded loops, and compile-time layout invariants, while keeping the repository's `snake_case` naming, 120-column limit, and ABI.
- Architecture and design work uses `improve-codebase-architecture`, `untangle-codebase`, `codebase-design`, `grilling`, `grill-me`, and `domain-modeling`. The architect is read-only; route implementation, report, and glossary/ADR writes to the developer or `zslay-docs`. The `untangle-codebase` copy removes `disable-model-invocation` so sub-agents can load it; test pruning stays opt-in and the test suite remains the refactor safety net.
- Review work uses `thermo-nuclear-code-quality-review` for strict maintainability findings and `untangle-codebase` for hidden-link, needless-link, surplus, and special-case findings in addition to the repository review checklist.
- Codebase questions use `graphify` before raw search when `graphify-out/graph.json` exists.
- Herdr orchestration uses the `herdr` skill only when the user explicitly asks for Herdr; the skill requires `HERDR_ENV=1` and never replaces the ownership rules above.

## Build, Test, and Development Commands

Enter the pinned Zig 0.17.1 environment before development:

```bash
nix develop                 # open the reproducible development shell
zig build                   # build the static library
zig build check             # compile and semantically check library and tests
zig build test              # run the Zig test suite
zig fmt --check .           # verify formatting without modifying files
pre-commit run --all-files  # run repository hooks manually
```

Use `zig fmt .` to apply formatting. Do not install project tools globally with `apt`, `brew`, or `npm`.

## Coding Style & Naming Conventions

Follow `zig fmt`: four-space indentation and a 120-character line limit. Use `snake_case` for files, functions, and variables; use `PascalCase` for types and type-level constants. Prefix exported C functions with `zslay_`. Prefer early returns, explicit error sets, shallow control flow, and sparse comments. Keep parser loops iterative with early returns rather than recursive. Do not use emojis in code, documentation, branches, or commits. Preserve ABI-safe pointer-plus-length boundaries instead of exposing Zig slices to C.

Define public types at file scope with explicit names. Extract repeated or inline type expressions into named aliases (for example `FrameHeaderBuffer`, `FrameQueue`, or C callback typedefs) instead of nesting types inside containers. Prefer `_len` for byte counts and `_sent` for stream progress over ambiguous names such as `extended_len` or `sent_header`.

## Testing Guidelines

Use Zig `test` blocks in `src/test.zig`, named `<Area>: <behavior>`, such as `Frame: decode simple unmasked text frame`. Add focused regression tests for parser, queue, layout, masking, and state-machine changes. No numeric coverage target is defined; changed behavior must be exercised. Run `zig build test` before opening a pull request.

## Commit & Pull Request Guidelines

History follows conventional commits: `<type>(<scope>): <imperative subject>`, for example `fix(queue): handle wrapped tail index`. Common types are `feat`, `fix`, `perf`, `build`, `ci`, `docs`, `style`, `refactor`, and `test`. Keep subjects lowercase and omit the trailing period.

Pull requests must explain what changed and why, identify the change type, link issues with `Closes #123` when applicable, and confirm formatting and tests. Screenshots are only useful for documentation or branding changes with visible output.

## graphify

This project has a knowledge graph at `graphify-out/` with god nodes, community structure, and cross-file relationships. The graph is installed for OpenCode (`.opencode/skills/graphify/`, `.opencode/plugins/graphify.js`) and Codex (`.codex/skills/graphify/`, `.codex/hooks.json`). `graphify-out/` is gitignored; rebuild it locally with `graphify update .`.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- When `graphify-out/graph.json` exists, run `graphify query "<question>"` before the first grep, search, or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than `GRAPH_REPORT.md` or raw grep output.
- `graphify-out/` is a generated, gitignored artifact. Do not commit it or treat a large local diff as churn.
- If `graphify-out/wiki/index.md` exists, use it for broad navigation instead of raw source browsing.
- Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
