# Repository Guidelines

## Project Structure & Module Organization

The public Zig API starts in `src/root.zig`. Keep protocol types and layouts in `src/types.zig`, pure header and masking operations in `src/frame.zig`, caller-backed collections in `src/queue.zig`, connection state in `src/event.zig`, and C ABI exports in `src/c_api.zig`. Tests live in `src/test.zig`; the README banner is under `misc/`. Build configuration is in `build.zig`, `build.zig.zon`, and `flake.nix`. See `CODEBASE.md` for the full file map.

Core code must remain zero-allocation and I/O-agnostic. Use caller-provided buffers, flat data layouts, static dispatch, and explicit integer-backed FFI types. Do not add socket operations or heap allocators to parser paths.

## Functional Core

`src/frame.zig` must stay pure: given the same input it returns the same output and writes only into caller-owned buffers. All mutation lives in `src/queue.zig` and `src/event.Conn`, reached exclusively through caller-provided context pointers. Use flat iterative loops with early returns; recursion, dynamic dispatch, and silent fallbacks are prohibited. Invalid input returns a typed error instead of a substituted default.

## Sub-Agent Directory

`.opencode/agents/` and `.codex/agents/` provide matching specialized agents for parser, event-loop, C ABI, Node-API, tests, review, release, and docs work. Both also provide an `architect` → `developer` → `reviewer` → `integrator` team procedure. Read `AGENT_DIRECTORY.md` for the roster, ownership map, workflow, and skill coverage. Each agent follows its listed skills and repository checks. Keep one owner per pull request scope and hand cross-scope work to the owning specialist.

## Skills

Shared project skills live in `.agents/skills/` and are locked by `skills-lock.json`. Platform copies from the graphify installer live in `.opencode/skills/graphify/` and `.codex/skills/graphify/` and are version-stamped by `.graphify_version`. `SKILL.md` is the human-readable catalog; `AGENT_DIRECTORY.md` is the source of truth for agent-to-skill coverage.

- Zig work uses `zig-0-17`, `zig-best-practices`, and `zig-testing`. The repository pins Zig 0.17.0 in `flake.nix` and `build.zig.zon`; apply the 0.17 guidance directly.
- Architecture and design work uses `improve-codebase-architecture`, `codebase-design`, `grilling`, `grill-me`, and `domain-modeling`. The architect is read-only; route report and glossary/ADR writes to the developer or `zslay-docs`.
- Review work uses `thermo-nuclear-code-quality-review` for strict maintainability findings in addition to the repository review checklist.
- JavaScript and TypeScript tooling under Node bindings uses `install-anti-slop` once `bindings/node/` and an Oxlint configuration exist; the skill is staged until then.
- Codebase questions use `graphify` before raw search when `graphify-out/graph.json` exists.

## Build, Test, and Development Commands

Enter the pinned Zig 0.17.0 environment before development:

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
