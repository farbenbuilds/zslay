# Global SKILL.md

This document summarizes the AI agent skills configured for the `zslay` project (version 0.2.1). `AGENT_DIRECTORY.md` is the source of truth for agent ownership and skill coverage.

## Core Project Skills

- **zslay-c-ffi**: C ABI / FFI boundary rules for `src/c_api.zig` and FFI-facing types in `src/types.zig`.
- **zslay-dod**: Data-oriented design constraints for core parser logic, structs, and state machines.
- **zslay-style**: Linux Kernel Zig style for writing, formatting, and refactoring code.
- **wslay-porting**: Porting and optimization guidance for the original wslay C implementation.

## Zig and Tooling Skills

- **zig-0-17**: Zig 0.17.0 API guidance and porting notes for `@backingInt`/`@fromBackingInt`, `SafeAllocator`, Struct-of-Arrays reflection, and the build system split. The repository still pins Zig 0.16.0 in `flake.nix` and `build.zig.zon`, so apply this skill as migration guidance until the toolchain pin changes.
- **zig-best-practices**: Used when reading or writing Zig files (`.zig`, `build.zig`, `build.zig.zon`).
- **zig-testing**: Test authoring, test allocators, filters, comptime tests, and fuzz testing.
- **nix-best-practices**: Nix flakes, overlays, `shell.nix`, and `flake.nix` work.
- **nix-hermetic**: Hermetic build and CI constraints for the zslay project.
- **install-anti-slop**: Install and maintain vendored anti-slop Oxlint plugins for JavaScript and TypeScript tooling under the Node bindings. Staged for the future `bindings/node/` tree; do not run the installer until that tree and an Oxlint configuration exist.
- **graphify**: Query the repository knowledge graph before broad source reads when `graphify-out/graph.json` exists. `graphify` is an optional host tool; install it explicitly with `uv tool install 'graphifyy==0.9.92'` rather than letting an agent install it globally.

## Architecture and Review Skills

- **improve-codebase-architecture**: Scan the codebase for deepening opportunities and present a visual HTML report. Uses `codebase-design`, `grilling`, and `domain-modeling`.
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

## Skill Locations and Dependencies

- Shared project skills live in `.agents/skills/` and are recorded in `skills-lock.json`.
- OpenCode-specific skills from the graphify installer live in `.opencode/skills/graphify/`; the reminder plugin is `.opencode/plugins/graphify.js`. The installer version-stamps this copy with `.graphify_version` instead of the project lock.
- Codex-specific skills from the graphify installer live in `.codex/skills/graphify/`; the hook is `.codex/hooks.json`, a no-op compatibility hook because graph guidance comes from `AGENTS.md`.
- `grill-me` delegates to `grilling`. `improve-codebase-architecture` depends on `codebase-design`, `grilling`, and `domain-modeling`; the read-only architect uses only the exploration and grilling phases and hands report or domain-doc writes to the developer or `zslay-docs`.
- The architecture and strict-review skills are model-invocable so sub-agents can load them. The local edits remove `disable-model-invocation` and the companion OpenAI manifest policy; a future `npx skills update` may restore both, so recheck the frontmatter and `agents/openai.yaml` files.

## Sub-Agent Directory

`.opencode/agents/` and `.codex/agents/` define matching specialized agents that load these skills before editing. OpenCode team roles live in `.opencode/agents/team/`; Codex uses project TOML files and `.codex/config.toml`:

| Agent | Area | Skills |
| --- | --- | --- |
| `zslay-parser` | Pure parser core (`src/types.zig`, `src/frame.zig`, `src/queue.zig`) | zslay-style, zslay-dod, dod, wslay-porting, Pragmatic Functional Programming, zig-0-17, zig-best-practices, graphify |
| `zslay-event-loop` | RX/TX state machine (`src/event.zig`) | zslay-style, zslay-dod, dod, Pragmatic Functional Programming, zig-0-17, zig-best-practices, graphify |
| `zslay-c-abi` | C exports and header (`src/c_api.zig`, `include/zslay.h`) | zslay-c-ffi, zslay-style, zig-0-17, zig-best-practices, graphify |
| `zslay-node-api` | Node-API bindings (`bindings/node/`) | zslay-c-ffi, nix-hermetic, nix-best-practices, zig-0-17, zig-best-practices, context7, install-anti-slop, graphify |
| `zslay-testing` | Test suite (`src/test.zig`) | zig-testing, zslay-style, zslay-dod, zig-0-17, zig-best-practices, graphify |
| `zslay-review` | Read-only review of changed files | zslay-style, zslay-dod, zslay-c-ffi, Pragmatic Functional Programming, ponytail, github-git, thermo-nuclear-code-quality-review, codebase-design, graphify |
| `zslay-release` | Build, packaging, CI (`build.zig`, `flake.nix`, `.github/`) | nix-hermetic, nix-best-practices, github-git, ponytail, graphify |
| `zslay-docs` | Documentation (root `*.md` guides) | github-git, caveman, ponytail, context7, domain-modeling, graphify |
| `team/architect` | Read-only planning and ownership routing | Pragmatic Functional Programming, ponytail, zslay-style, improve-codebase-architecture, codebase-design, grilling, grill-me, graphify |
| `team/developer` | Implementation coordination | matched specialist skills, codebase-design, graphify |
| `team/reviewer` | Read-only quality gate | zslay-style, zslay-dod, zslay-c-ffi, Pragmatic Functional Programming, ponytail, github-git, thermo-nuclear-code-quality-review, codebase-design, graphify |
| `team/integrator` | Resolve findings and final verification | github-git, ponytail, zslay-style, codebase-design, graphify |

Every skill above is assigned to at least one agent. See `AGENT_DIRECTORY.md` for delegation rules, ownership boundaries, and the full coverage matrix.

The coordinated team follows `architect` → `developer` → `reviewer` → `integrator`. The architect plans and routes work; the developer coordinates the existing specialist agents; the reviewer is read-only; the integrator resolves findings through file owners and checks the final diff. Agent and documentation updates do not require a package version bump.
