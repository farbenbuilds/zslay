# Codebase Map

`zslay` is a zero-allocation, I/O-agnostic WebSocket framing library written in Zig 0.17.1. Callers own buffers and network I/O; the library parses, serializes, masks, and tracks frame state.

## Runtime Flow

Incoming bytes move through `event.Conn`, which collects a header, delegates validation and decoding to `frame.zig`, and returns an `RxAction` telling the caller what to provide or consume next. Outgoing frames are prepared by `event.Conn`, stored in the caller-backed queue, and exposed through `TxAction`. `c_api.zig` adapts this flow to C callbacks and opaque pointers.

## Functional Core

`src/frame.zig` and the pure helpers in `src/event.zig` are side-effect free: the same input always produces the same output, and writes target only caller-owned buffers. Mutation is confined to `src/queue.zig` and `src/event.Conn`, which operate exclusively on caller-provided storage. Parser paths use flat iterative loops with early returns; recursion, dynamic dispatch, and silent fallbacks are not used, and invalid input yields a typed error.

## Type Conventions

Types are plain, top-level declarations with explicit names. Repeated or inline type expressions become named aliases (`FrameHeaderBuffer`, `FrameQueue`, and the C callback typedefs) instead of anonymous nesting. `ConnConfig` and `FrameNode` live at file scope; `Conn.Config` remains only as a compatibility alias. Length fields use `_len` for byte counts and `_sent` for stream progress, so signatures read without decoding magic numbers.

## Source Files

| File | Purpose |
| --- | --- |
| `src/types.zig` | Defines RFC 6455 opcodes, close codes, parser errors, packed frame headers, and the named size aliases `MaskingKeyLen`, `MaskingKey`, `MaxFrameHeaderLen`, and `FrameHeaderBuffer`. |
| `src/frame.zig` | Pure functions that encode and decode frame headers, derive the canonical wire length marker from the payload length, resolve canonical lengths into `DecodedHeader`, calculate serialized sizes, derive header byte counts, mask payloads in place, and validate close payloads. Strict `decode_header`/`encode_header` wrappers remain the default; `Rsv1Options` variants gate only the RSV1 bit, and RSV2/RSV3 stay rejected. |
| `src/queue.zig` | Implements a generic bounded deque `Queue(Element)` over caller-provided storage; it performs no allocation. |
| `src/event.zig` | Holds the iterative receive/transmit state machine, `ConnConfig` with opt-in `allow_rsv1`, `FrameOptions`, `FrameNode` and its `rsv1()` header accessor, `FragmentState`, the concrete `FrameQueue` alias, checked RX current-frame/remaining and TX overlap accessors, ping/pong preemption, and RFC 7692 first-data-frame RSV1 shape enforcement. |
| `src/c_api.zig` | Exports the role-aware, bounded C ABI at revision 2, validates opaque handles, guards callback reentrancy, stages receive prefixes, enforces callback/byte send budgets and payload-overlap rules, and bridges caller-owned storage to the Zig state machine through `Conn` accessors rather than queue internals. The C API remains strict with no RSV1 option or frame bit. |
| `src/root.zig` | Defines the public Zig module and re-exports the supported API. |
| `src/test.zig` | Tests layouts, queues, frame encoding/decoding, masking, TX accessors, malformed-input resilience, strict/default and negotiated RSV1 behavior, C ABI handles and revision 2, partial sends, and reentrancy. |
| `src/bench.zig` | Standalone, in-process benchmark for header operations, payload masking, and receive state transitions; prints JSON via `zig build bench -Doptimize=ReleaseFast` and is excluded from the unit test suite. |
| `benchmarks/echo_server.c` | Loopback WebSocket echo adapter with chunked handshakes, pipelined-input draining, an 8 KiB receive buffer, idle retirement, and separate node/transmit storage; built by `zig build bench-echo`. |
| `src/c_api_smoke.c` | C11 ABI smoke test compiled and linked against the installed `zslay.h` and static library; executed by `zig build test`. |

## Build and Environment

| File | Purpose |
| --- | --- |
| `build.zig` | Builds the Zig module and static C library; defines `test`, `bench`, `bench-echo`, and `check` steps. The `test` step runs Debug and ReleaseSafe suites and compiles, links, and runs the C ABI smoke test. |
| `build.zig.zon` | Stores package metadata, the minimum Zig version, and published paths. |
| `include/zslay.h` | Declares the installed C ABI at revision 2, callback/reentrancy contracts, result codes, storage alignment, and borrowed-memory lifetimes. The C surface remains strict and has no RSV1 option or frame bit. |
| `flake.nix`, `flake.lock` | Pin the Nix development shell, checks, formatter, and cross-platform release builds. |
| `.envrc` | Loads the Nix flake through direnv. |
| `.pre-commit-config.yaml` | Configures local formatting and validation hooks. |
| `.gitattributes` | Excludes vendored agent tooling from GitHub language statistics and marks Zig package metadata. |

## Project Support Files

- `README.md` introduces the library and setup.
- `CONTRIBUTE.md` and `CODING_CONVENTION.md` define the contributor workflow and style.
- `SECURITY.md`, `CHANGELOG.md`, and `LICENSE` cover reporting, releases, and licensing.
- `CI_CD_PIPELINE.md` documents CI and publishing; `.github/` contains workflows and community templates.
- `benchmarks/CONTRACT.md` defines the in-process benchmark cases, result units, and history rules. Case definitions live in `src/bench.zig`; `scripts/benchmark_history.py` publishes results to the separate `benchmark-data` branch.
- `benchmarks/ECHO_CONTRACT.md` defines the loopback echo workload and metrics. `scripts/benchmark_echo.py` supplies the independent standard-library client; the `benchmark-data` branch keeps echo records under `echo/`.
- `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, `.agents/`, and `skills-lock.json` contain repository-specific AI agent guidance.
- `AGENT_DIRECTORY.md` maps the specialized sub-agents to owned paths, delegation rules, and skill coverage.
- `.opencode/agents/`, `.codex/agents/`, and `.agents/agents/` hold the sub-agent definitions that each client discovers.
- `.opencode/skills/graphify/` and `.codex/skills/graphify/` hold the platform-specific graphify skill. `.opencode/plugins/graphify.js` injects the reminder; `.codex/hooks.json` is a no-op compatibility hook because Codex takes graph guidance from `AGENTS.md`. `graphify-out/` stays local and gitignored.
- `misc/zslay-banner.png` is the README banner asset.
