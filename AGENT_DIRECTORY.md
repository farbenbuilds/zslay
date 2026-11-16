# zslay - Agent Directory

Specialized sub-agents for the `zslay` repository. Each agent owns a narrow slice of the codebase, loads a fixed set of skills, and verifies its work with the repository commands. This document is the single source of truth for the agent roster, ownership map,
and skill coverage.

For contributor workflow see [CONTRIBUTE.md](CONTRIBUTE.md); for code style see [CODING_CONVENTION.md](CODING_CONVENTION.md); for architecture see [CODEBASE.md](CODEBASE.md).

## Layout

| Path | Purpose |
| --- | --- |
| `.opencode/agents/<name>.md` | OpenCode sub-agent definitions, auto-discovered by the project. |
| `.opencode/agents/team/` | OpenCode architect, developer, reviewer, and integrator roles. |
| `.codex/agents/<name>.toml` | Codex project-scoped custom agents. |
| `.codex/config.toml` | Codex agent and multi-agent feature configuration. |
| `.agents/agents/<name>.md` | agy custom agents, auto-discovered from the workspace customization root. |
| `.agents/skills/<name>/SKILL.md` | Shared project skills loaded by the agents and locked in `skills-lock.json`. |
| `.opencode/skills/graphify/` | Graphify skill installed for OpenCode by `graphify install --platform opencode --project`. |
| `.opencode/plugins/graphify.js` | OpenCode 1.x/2.x plugin that injects the graph reminder before the first shell command. |
| `.codex/skills/graphify/` | Graphify skill installed for Codex by `graphify install --platform codex --project`. |
| `.codex/hooks.json` | Codex PreToolUse hook registered by the graphify installer. |
| `skills-lock.json` | Pinned skill sources, paths, and hashes. |
| `AGENTS.md` | Repository-wide rules that every agent must follow. |
| `CLAUDE.md` | Claude Code entry point; imports `AGENTS.md`. |
| `SKILL.md` | Human-readable skill summary and agent-to-skill coverage. |

## Roster

| Agent | Area | Owned paths | Clients |
| --- | --- | --- | --- |
| `zslay-parser` / `zslay_parser` | Pure parser core | `src/types.zig`, `src/frame.zig`, `src/queue.zig` | OpenCode, Codex, agy |
| `zslay-event-loop` / `zslay_event_loop` | RX/TX state machine | `src/event.zig` | OpenCode, Codex, agy |
| `zslay-c-abi` / `zslay_c_abi` | C ABI surface | `src/c_api.zig`, `include/zslay.h` | OpenCode, Codex, agy |
| `zslay-node-api` / `zslay_node_api` | Node-API bindings | `bindings/node/` | OpenCode, Codex, agy |
| `zslay-testing` / `zslay_testing` | Test suite | `src/test.zig` | OpenCode, Codex, agy |
| `zslay-review` / `zslay_review` | Read-only review | any changed file | OpenCode, Codex, agy |
| `zslay-release` / `zslay_release` | Build, packaging, CI | `build.zig`, `build.zig.zon`, `flake.nix`, `.github/workflows/` | OpenCode, Codex, agy |
| `zslay-docs` / `zslay_docs` | Documentation | repository documentation | OpenCode, Codex, agy |
| `team/architect` / `zslay_architect` / `zslay-architect` | Read-only planning and ownership routing | affected paths | OpenCode, Codex, agy |
| `team/developer` / `zslay_developer` / `zslay-developer` | Implementation coordination | specialist-owned paths | OpenCode, Codex, agy |
| `team/reviewer` / `zslay_reviewer` / `zslay-reviewer` | Read-only quality gate | any changed file | OpenCode, Codex, agy |
| `team/integrator` / `zslay_integrator` / `zslay-integrator` | Resolve findings and final verification | affected paths through their owners | OpenCode, Codex, agy |

OpenCode and agy use hyphenated names; Codex uses underscore names. The agy definitions live in `.agents/agents/` and are selected with `agy --agent <name>` or the `/agents` picker.

## Skill Coverage

Every repository skill is loaded by at least one agent. The agy agents mirror these assignments through the `skills` frontmatter in `.agents/agents/*.md`, referencing the shared folders under `.agents/skills/`. agy runs the `graphify` CLI directly because the graphify skill copies are platform-specific to OpenCode and Codex.

| Skill | Loaded by |
| --- | --- |
| `zslay-style` | parser, event-loop, c-abi, testing, review, team architect, team reviewer, team integrator |
| `zslay-dod` | parser, event-loop, testing, review, team reviewer |
| `zslay-c-ffi` | c-abi, node-api, review, team reviewer |
| `wslay-porting` | parser |
| `zig-0-17` | parser, event-loop, c-abi, node-api, testing |
| `zig-best-practices` | parser, event-loop, c-abi, node-api, testing |
| `zig-tiger-style` | parser, event-loop, c-abi, node-api, testing, review, team architect, team developer, team reviewer, team integrator |
| `zig-testing` | testing |
| `nix-best-practices` | node-api, release |
| `nix-hermetic` | node-api, release |
| `Pragmatic Functional Programming` | parser, event-loop, review, team architect, team reviewer |
| `caveman` | docs |
| `ponytail` | review, release, docs, team architect, team reviewer, team integrator |
| `context7` | node-api, docs |
| `herdr` | team architect, team developer, team integrator |
| `dod` | parser, event-loop |
| `github-git` | review, release, docs, team reviewer, team integrator |
| `graphify` | parser, event-loop, c-abi, node-api, testing, review, release, docs, team architect, team developer, team reviewer, team integrator |
| `improve-codebase-architecture` | team architect |
| `codebase-design` | review, team architect, team developer, team reviewer, team integrator |
| `grilling` | team architect |
| `grill-me` | team architect |
| `domain-modeling` | docs |
| `thermo-nuclear-code-quality-review` | review, team reviewer |
| `install-anti-slop` | node-api (staged until `bindings/node/` and Oxlint configuration exist) |

`zig-0-17` is the active toolchain guidance. The repository pins Zig 0.17.1 in `flake.nix` and `build.zig.zon`; use 0.17 APIs directly.

`zig-tiger-style` adds TigerBeetle-style safety and performance guidance: explicit control flow, entry assertions for programmer errors, bounded loops, compile-time layout invariants, and unit-qualified names. Apply its safety ideas without changing the repository's `snake_case` naming, public API, C ABI, or zero-allocation design.

`herdr` is generated from the installed Herdr CLI with `herdr --skill`. It applies only when the user explicitly asks for Herdr orchestration and requires `HERDR_ENV=1`; it never overrides the ownership and non-delegation rules in `AGENTS.md`. Regenerate the skill after upgrading Herdr and refresh its lock hash.

The `zig-tiger-style` copy carries a local zslay override for naming and formatting; reapply it if `npx skills update` restores the upstream file.

`grill-me` delegates to `grilling`. `improve-codebase-architecture` uses `codebase-design`, `grilling`, and `domain-modeling`; the read-only architect runs only the exploration and grilling phases and hands report or domain-doc writes to the developer or `zslay-docs`. The architecture and strict-review skills are model-invocable so sub-agents can load them; a future `npx skills update` may restore the upstream `disable-model-invocation` flag and the OpenAI manifest policy.

## Delegation Rules

1. For coordinated work, follow `architect` → `developer` → `reviewer` → `integrator`. The architect identifies owners and dependencies; the developer delegates implementation to the matching specialist; the reviewer is read-only; the integrator routes findings to their owners and checks the final diff. Keep dependent stages sequential and do not let agents edit the same files concurrently.
2. Route one scope per pull request. Parser-only edits go to `zslay-parser`, state transitions to `zslay-event-loop`,
   C boundary changes to `zslay-c-abi`, Node.js work to `zslay-node-api`, coverage to `zslay-testing`, pipeline work to
   `zslay-release`, and prose to `zslay-docs`.
3. Cross-scope changes are handed off between agents, not merged into one pass. For example, a new C export requested by `zslay-node-api` is implemented by `zslay-c-abi` first.
4. Every agent reads its listed skills from `.agents/skills/`, `.opencode/skills/`, or `.codex/skills/` before editing, then follows `AGENTS.md` and `CODING_CONVENTION.md`.
5. Code changes use `zig fmt --check .`, `zig build test`, and `zig build check`; documentation-only changes use `pre-commit run --all-files` and check links/fences.
6. `zslay-review` and team reviewers are read-only and must review before opening or merging a pull request.
7. No agent commits, pushes, tags, or opens pull requests unless the user explicitly asks.
8. Keep core code zero-allocation and I/O-agnostic; the Node-API binding layer is the only place allocation is allowed, and only for Node-owned memory.
9. For codebase questions, run `graphify query` before raw search when `graphify-out/graph.json` exists. Use `graphify path` and `graphify explain` for relationships and focused concepts, and run `graphify update .` after code changes.
10. Route architecture sweeps through the architect with `improve-codebase-architecture`, `codebase-design`, and `grilling`; route strict maintainability review through `zslay-review` or the team reviewer with `thermo-nuclear-code-quality-review`. The architect is read-only: report and domain-document writes go to the developer or `zslay-docs`.
11. agy agents live in `.agents/agents/` and load the same roster from `.agents/skills/`. Start them with `agy --agent zslay-<role>` or the `/agents` picker; for unattended worker panes add `--mode auto`. Herdr starts an agy worker with `--kind agy` and passes `--agent zslay-<role> --mode auto` after `--`.

## Invoking an Agent

- opencode TUI: mention the agent by name, for example `@zslay-parser decode the extended length boundary`.
- agy: use `agy --agent zslay-parser`, `agy --agent zslay-architect`, or the `/agents` picker. For unattended worker panes, add `--mode auto`. In Herdr, use `herdr agent start parser --kind agy --pane <pane-id> -- --agent zslay-parser --mode auto`.
- Programmatic orchestration: dispatch the agent by name through the task tool and pass the exact paths, the behavior to change, and the verification command.
- In every invocation, state the scope boundary so the agent does not edit files owned by another agent.

## Adding or Changing an Agent

1. Add an OpenCode Markdown definition in `.opencode/agents/`, a Codex TOML definition in `.codex/agents/`, and an agy Markdown definition in `.agents/agents/`, each with the native required fields and matching ownership guidance.
2. List the exact existing skills and keep scope disjoint from existing specialists.
3. Install new skills with `npx skills add` so `.agents/skills/` and `skills-lock.json` stay in sync. Keep graphify-specific skills in `.opencode/skills/` and `.codex/skills/`.
4. Update the roster and skill coverage tables here and the summary in `SKILL.md`.
5. Restart the relevant agent client after changing definitions so it reloads configuration.
