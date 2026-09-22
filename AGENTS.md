# Repository Guidelines

## Project Structure & Module Organization

The public Zig API starts in `src/root.zig`. Keep protocol types and layouts in `src/types.zig`, pure header and masking operations in `src/frame.zig`, caller-backed collections in `src/queue.zig`, connection state in `src/event.zig`, and C ABI exports in `src/c_api.zig`. Tests live in `src/test.zig`; the README banner is under `misc/`. Build configuration is in `build.zig`, `build.zig.zon`, and `flake.nix`. See `CODEBASE.md` for the full file map.

Core code must remain zero-allocation and I/O-agnostic. Use caller-provided buffers, flat data layouts, static dispatch, and explicit integer-backed FFI types. Do not add socket operations or heap allocators to parser paths.

## Functional Core

`src/frame.zig` must stay pure: given the same input it returns the same output and writes only into caller-owned buffers. All mutation lives in `src/queue.zig` and `src/event.Conn`, reached exclusively through caller-provided context pointers. Use flat iterative loops with early returns; recursion, dynamic dispatch, and silent fallbacks are prohibited. Invalid input returns a typed error instead of a substituted default.

## Sub-Agent Directory

`.opencode/agents/` defines specialized sub-agents: `zslay-parser` (pure parser core), `zslay-event-loop` (RX/TX state machine), `zslay-c-abi` (C exports and header), `zslay-node-api` (Node-API bindings), `zslay-testing` (test suite), `zslay-review` (read-only review), `zslay-release` (build and CI), and `zslay-docs` (documentation). Each agent loads its listed skills from `.agents/skills/` before editing and verifies with `zig build test` and `zig fmt --check .`. See `AGENT_DIRECTORY.md` for the roster, ownership map, and skill coverage matrix. Keep one agent per pull request scope and hand cross-scope work to the owning agent.

## Build, Test, and Development Commands

Enter the pinned Zig 0.16.0 environment before development:

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
