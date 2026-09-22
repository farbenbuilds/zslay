# zslay - Agent Directory

Specialized sub-agents for the `zslay` repository. Each agent owns a narrow slice of the codebase, loads a fixed set of skills, and verifies its work with the repository commands. This document is the single source of truth for the agent roster, ownership map,
and skill coverage.

For contributor workflow see [CONTRIBUTE.md](CONTRIBUTE.md); for code style see [CODING_CONVENTION.md](CODING_CONVENTION.md); for architecture see [CODEBASE.md](CODEBASE.md).

## Layout

| Path | Purpose |
| --- | --- |
| `.opencode/agents/<name>.md` | Sub-agent definitions. opencode auto-discovers project agents here. |
| `.agents/skills/<name>/SKILL.md` | Skills loaded by the agents. Auto-discovered by opencode. |
| `AGENTS.md` | Repository-wide rules that every agent must follow. |
| `SKILL.md` | Human-readable skill summary and agent-to-skill coverage. |

## Roster

| Agent | Area | Owned paths | Mode |
| --- | --- | --- | --- |
| `zslay-parser` | Pure parser core | `src/types.zig`, `src/frame.zig`, `src/queue.zig` | subagent |
| `zslay-event-loop` | RX/TX state machine | `src/event.zig` | subagent |
| `zslay-c-abi` | C ABI surface | `src/c_api.zig`, `include/zslay.h` | subagent |
| `zslay-node-api` | Node-API bindings | `bindings/node/` | subagent |
| `zslay-testing` | Test suite | `src/test.zig` | subagent |
| `zslay-review` | Read-only review | any changed file | subagent |
| `zslay-release` | Build, packaging, CI | `build.zig`, `build.zig.zon`, `flake.nix`, `.github/workflows/` | subagent |
| `zslay-docs` | Documentation | `README.md`, `CODEBASE.md`, `CONTRIBUTE.md`, `AGENTS.md`, `SKILL.md`, `CHANGELOG.md` | subagent |

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

1. Route one scope per pull request. Parser-only edits go to `zslay-parser`, state transitions to `zslay-event-loop`,
   C boundary changes to `zslay-c-abi`, Node.js work to `zslay-node-api`, coverage to `zslay-testing`, pipeline work to
   `zslay-release`, and prose to `zslay-docs`.
2. Cross-scope changes are handed off between agents, not merged into a single pass. For example, a new C export requested by `zslay-node-api` is implemented by `zslay-c-abi` first.
3. Every agent loads its listed skills with the skill tool before editing, then follows `AGENTS.md` and `CODING_CONVENTION.md`.
4. Every agent verifies with `zig fmt --check .` (or `zig fmt .`), `zig build test`, and `zig build check`; documentation-only changes use `pre-commit run --all-files`.
5. `zslay-review` is read-only (`edit: deny`) and must be used before opening or merging a pull request.
6. No agent commits, pushes, tags, or opens pull requests unless the user explicitly asks.
7. Keep core code zero-allocation and I/O-agnostic; the Node-API binding layer is the only place allocation is allowed, and only for Node-owned memory.

## Invoking an Agent

- opencode TUI: mention the agent by name, for example `@zslay-parser decode the extended length boundary`.
- Programmatic orchestration: dispatch the agent by name through the task tool and pass the exact paths, the behavior to change, and the verification command.
- In every invocation, state the scope boundary so the agent does not edit files owned by another agent.

## Adding or Changing an Agent

1. Create `.opencode/agents/<name>.md` with frontmatter `description`, `mode: subagent`, and optional `color`, `temperature`, `permission`.
2. In the body, list the required skills by their exact skill names and keep the scope disjoint from existing agents.
3. Update the roster and skill coverage tables in this file and the summary in `SKILL.md`.
4. Restart opencode after changing agent definitions; configuration is loaded once at startup.
