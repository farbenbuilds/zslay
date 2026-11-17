# Global SKILL.md

This document summarizes the AI agent skills configured for the `zslay` project (version 0.4.5). `AGENT_DIRECTORY.md` is the source of truth for agent ownership and skill coverage.

## Core Project Skills

- **zslay-c-ffi**: C ABI / FFI boundary rules for `src/c_api.zig` and FFI-facing types in `src/types.zig`.
- **zslay-dod**: Data-oriented design constraints for core parser logic, structs, and state machines.
- **zslay-style**: Linux Kernel Zig style for writing, formatting, and refactoring code.
- **wslay-porting**: Porting and optimization guidance for the original wslay C implementation.

## Zig and Tooling Skills

- **zig-0-17**: Zig 0.17.1 API guidance and porting notes for `@backingInt`/`@fromBackingInt`, `SafeAllocator`, Struct-of-Arrays reflection, and the build system split. The repository pins Zig 0.17.1 in `flake.nix` and `build.zig.zon`; apply this skill directly.
- **zig-best-practices**: Used when reading or writing Zig files (`.zig`, `build.zig`, `build.zig.zon`).
- **zig-tiger-style**: TigerStyle safety, performance, and naming guidance distilled from TigerBeetle. Use it for assertions, bounded loops, explicit control flow, memory layout, and compile-time invariants. Apply the safety ideas while keeping the repository's `snake_case` naming and ABI conventions.
- **zig-testing**: Test authoring, test allocators, filters, comptime tests, and fuzz testing.
- **nix-best-practices**: Nix flakes, overlays, `shell.nix`, and `flake.nix` work.
- **nix-hermetic**: Hermetic build and CI constraints for the zslay project.
- **graphify**: Query the repository knowledge graph before broad source reads when `graphify-out/graph.json` exists. `graphify` is an optional host tool; install it explicitly with `uv tool install 'graphifyy==0.9.92'` rather than letting an agent install it globally.

## Architecture and Review Skills

- **improve-codebase-architecture**: Scan the codebase for deepening opportunities and present a visual HTML report. Uses `codebase-design`, `grilling`, and `domain-modeling`.
- **untangle-codebase**: Untangle the codebase in one pass by listing hidden links, needless links, surplus, and special cases, redesigning from first principles, then refactoring and rechecking. Use for whole-codebase structural refactors; comment cleanup is in scope and test pruning stays opt-in.
- **codebase-design**: Shared deep-module vocabulary for interfaces, seams, adapters, leverage, and locality.
- **grilling**: Relentless design-tree interview that stress-tests a plan or decision.
- **grill-me**: Short user-facing trigger that delegates to `grilling`.
- **domain-modeling**: Maintain `GLOSSARY.md` and ADRs while domain decisions crystallize. The `zslay-docs` agent owns those writes.
- **thermo-nuclear-code-quality-review**: Strict maintainability review for abstraction quality, file growth, and spaghetti-condition growth.
- **Pragmatic Functional Programming**: Practical functional-programming guidance for pure transforms and explicit state.
- **dod**: General data-oriented design review of memory layout, locality, and throughput.
- **ponytail**: YAGNI and minimal-solution enforcement.
- **context7**: Retrieve current external library and API documentation.
- **caveman**: Terse, token-efficient prose.
- **github-git**: Git and GitHub workflow rules, including conventional commits and pre-push checks.
- **herdr**: Control Herdr panes, agents, and workspaces when the user explicitly asks for Herdr orchestration. Requires `HERDR_ENV=1`; it does not replace the repository ownership rules.

## Skill Locations and Dependencies

- Shared project skills live in `.agents/skills/` and are recorded in `skills-lock.json`.
- agy custom agents live in `.agents/agents/` and reference the shared skills through their `skills` frontmatter. agy runs the `graphify` CLI directly; the graphify skill copies remain platform-specific to OpenCode and Codex.
- OpenCode-specific skills from the graphify installer live in `.opencode/skills/graphify/`; the reminder plugin is `.opencode/plugins/graphify.js`. The installer version-stamps this copy with `.graphify_version` instead of the project lock.
- Codex-specific skills from the graphify installer live in `.codex/skills/graphify/`; the hook is `.codex/hooks.json`, a no-op compatibility hook because graph guidance comes from `AGENTS.md`.
- `grill-me` delegates to `grilling`. `improve-codebase-architecture` depends on `codebase-design`, `grilling`, and `domain-modeling`; the read-only architect uses only the exploration and grilling phases and hands report or domain-doc writes to the developer or `zslay-docs`.
- The architecture and strict-review skills are model-invocable so sub-agents can load them. The local edits remove `disable-model-invocation` and the companion OpenAI manifest policy; a future `npx skills update` may restore both, so recheck the frontmatter and `agents/openai.yaml` files.
- `untangle-codebase` carries its own local frontmatter override that removes `disable-model-invocation`; reapply it after `npx skills update`. The repository applies the core untangle pass plus comment cleanup and keeps test pruning opt-in. The read-only architect uses the problem-listing and redesign phases only; implementation belongs to the developer and specialists.
- `zig-tiger-style` carries a local zslay override that keeps `snake_case`, the 120-column limit, and the C ABI. Reapply that override after an upstream `npx skills update`.
- `.agents/skills/herdr/SKILL.md` is generated with `herdr --skill`; regenerate it after upgrading Herdr and recompute the lock hash.

## Sub-Agent Directory

`.opencode/agents/`, `.codex/agents/`, and `.agents/agents/` define matching specialized agents that load these skills before editing. OpenCode team roles live in `.opencode/agents/team/`; Codex uses project TOML files and `.codex/config.toml`; agy uses Markdown files under `.agents/agents/`:

| Agent | Area | Skills |
| --- | --- | --- |
| `zslay-parser` | Pure parser core (`src/types.zig`, `src/frame.zig`, `src/queue.zig`) | zslay-style, zslay-dod, dod, wslay-porting, Pragmatic Functional Programming, zig-0-17, zig-best-practices, zig-tiger-style, graphify |
| `zslay-event-loop` | RX/TX state machine (`src/event.zig`) | zslay-style, zslay-dod, dod, Pragmatic Functional Programming, zig-0-17, zig-best-practices, zig-tiger-style, graphify |
| `zslay-c-abi` | C exports and header (`src/c_api.zig`, `include/zslay.h`) | zslay-c-ffi, zslay-style, zig-0-17, zig-best-practices, zig-tiger-style, graphify |
| `zslay-node-api` | Node-API bindings (`bindings/node/`) | zslay-c-ffi, nix-hermetic, nix-best-practices, zig-0-17, zig-best-practices, zig-tiger-style, context7, graphify |
| `zslay-testing` | Test suite (`src/test.zig`) | zig-testing, zslay-style, zslay-dod, zig-0-17, zig-best-practices, zig-tiger-style, graphify |
| `zslay-review` | Read-only review of changed files | zslay-style, zslay-dod, zslay-c-ffi, Pragmatic Functional Programming, ponytail, github-git, thermo-nuclear-code-quality-review, untangle-codebase, codebase-design, zig-tiger-style, graphify |
| `zslay-release` | Build, packaging, CI (`build.zig`, `flake.nix`, `.github/`) | nix-hermetic, nix-best-practices, github-git, ponytail, graphify |
| `zslay-docs` | Documentation (root `*.md` guides) | github-git, caveman, ponytail, context7, domain-modeling, graphify |
| `team/architect` | Read-only planning and ownership routing | Pragmatic Functional Programming, ponytail, zslay-style, improve-codebase-architecture, untangle-codebase, codebase-design, grilling, grill-me, zig-tiger-style, herdr, graphify |
| `team/developer` | Implementation coordination | matched specialist skills, codebase-design, untangle-codebase, zig-tiger-style, herdr, graphify |
| `team/reviewer` | Read-only quality gate | zslay-style, zslay-dod, zslay-c-ffi, Pragmatic Functional Programming, ponytail, github-git, thermo-nuclear-code-quality-review, untangle-codebase, codebase-design, zig-tiger-style, graphify |
| `team/integrator` | Resolve findings and final verification | github-git, ponytail, zslay-style, codebase-design, untangle-codebase, zig-tiger-style, herdr, graphify |

agy uses the hyphenated names `zslay-parser`, `zslay-event-loop`, `zslay-c-abi`, `zslay-node-api`, `zslay-testing`, `zslay-review`, `zslay-release`, and `zslay-docs`, plus the team roles `zslay-architect`, `zslay-developer`, `zslay-reviewer`, and `zslay-integrator`.

Every skill above is assigned to at least one agent. See `AGENT_DIRECTORY.md` for delegation rules, ownership boundaries, and the full coverage matrix.

The coordinated team follows `architect` → `developer` → `reviewer` → `integrator`. The architect plans and routes work; the developer coordinates the existing specialist agents; the reviewer is read-only; the integrator resolves findings through file owners and checks the final diff. Agent and documentation updates do not require a package version bump.
