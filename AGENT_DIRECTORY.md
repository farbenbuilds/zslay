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
| `.codex/config.toml` | Codex agent concurrency configuration. |
| `.agents/skills/<name>/SKILL.md` | Skills loaded by the agents. Auto-discovered by opencode. |
| `AGENTS.md` | Repository-wide rules that every agent must follow. |
| `SKILL.md` | Human-readable skill summary and agent-to-skill coverage. |

## Roster

| Agent | Area | Owned paths | Mode |
| --- | --- | --- | --- |
| `zslay-parser` | Pure parser core | `src/types.zig`, `src/frame.zig`, `src/queue.zig` | OpenCode and Codex |
| `zslay-event-loop` | RX/TX state machine | `src/event.zig` | OpenCode and Codex |
| `zslay-c-abi` | C ABI surface | `src/c_api.zig`, `include/zslay.h` | OpenCode and Codex |
| `zslay-node-api` | Node-API bindings | `bindings/node/` | OpenCode and Codex |
| `zslay-testing` | Test suite | `src/test.zig` | OpenCode and Codex |
| `zslay-review` | Read-only review | any changed file | OpenCode and Codex |
| `zslay-release` | Build, packaging, CI | `build.zig`, `build.zig.zon`, `flake.nix`, `.github/workflows/` | OpenCode and Codex |
| `zslay-docs` | Documentation | repository documentation | OpenCode and Codex |
| `team/architect` / `zslay_architect` | Read-only planning and ownership routing | affected paths | OpenCode and Codex |
| `team/developer` / `zslay_developer` | Implementation coordination | specialist-owned paths | OpenCode and Codex |
| `team/reviewer` / `zslay_reviewer` | Read-only quality gate | any changed file | OpenCode and Codex |
| `team/integrator` / `zslay_integrator` | Resolve findings and final verification | affected paths through their owners | OpenCode and Codex |

## Skill Coverage

Every repository skill is loaded by at least one agent.

| Skill | Loaded by |
| --- | --- |
| `zslay-style` | parser, event-loop, c-abi, testing, review |
| `zslay-dod` | parser, event-loop, testing, review |
| `zslay-c-ffi` | c-abi, node-api, review |
| `wslay-porting` | parser |
| `zig-0.16` | parser, event-loop, c-abi, node-api, testing |
| `zig-best-practices` | parser, event-loop, c-abi, node-api, testing |
| `zig-testing` | testing |
| `nix-best-practices` | node-api, release |
| `nix-hermetic` | node-api, release |
| `Pragmatic Functional Programming` | parser, event-loop, review |
| `caveman` | docs |
| `ponytail` | review, release, docs |
| `context7` | node-api, docs |
| `dod` | parser, event-loop |
| `github-git` | review, release, docs |

## Delegation Rules

1. For coordinated work, follow `architect` → `developer` → `reviewer` → `integrator`. The architect identifies owners and dependencies; the developer delegates implementation to the matching specialist; the reviewer is read-only; the integrator routes findings to their owners and checks the final diff. Keep dependent stages sequential and do not let agents edit the same files concurrently.
2. Route one scope per pull request. Parser-only edits go to `zslay-parser`, state transitions to `zslay-event-loop`,
   C boundary changes to `zslay-c-abi`, Node.js work to `zslay-node-api`, coverage to `zslay-testing`, pipeline work to
   `zslay-release`, and prose to `zslay-docs`.
3. Cross-scope changes are handed off between agents, not merged into one pass. For example, a new C export requested by `zslay-node-api` is implemented by `zslay-c-abi` first.
4. Every agent reads its listed skills from `.agents/skills/` before editing, then follows `AGENTS.md` and `CODING_CONVENTION.md`.
5. Code changes use `zig fmt --check .`, `zig build test`, and `zig build check`; documentation-only changes use `pre-commit run --all-files` and check links/fences.
6. `zslay-review` and team reviewers are read-only and must review before opening or merging a pull request.
7. No agent commits, pushes, tags, or opens pull requests unless the user explicitly asks.
8. Keep core code zero-allocation and I/O-agnostic; the Node-API binding layer is the only place allocation is allowed, and only for Node-owned memory.

## Invoking an Agent

- opencode TUI: mention the agent by name, for example `@zslay-parser decode the extended length boundary`.
- Programmatic orchestration: dispatch the agent by name through the task tool and pass the exact paths, the behavior to change, and the verification command.
- In every invocation, state the scope boundary so the agent does not edit files owned by another agent.

## Adding or Changing an Agent

1. Add an OpenCode Markdown definition in `.opencode/agents/` and a Codex TOML definition in `.codex/agents/`, each with the native required fields and matching ownership guidance.
2. List the exact existing skills and keep scope disjoint from existing specialists.
3. Update the roster and skill coverage tables here and the summary in `SKILL.md`.
4. Restart the relevant agent client after changing definitions so it reloads configuration.
