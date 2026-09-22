# Codebase Map

`zslay` is a zero-allocation, I/O-agnostic WebSocket framing library written in Zig 0.16.0. Callers own buffers and network I/O; the library parses, serializes, masks, and tracks frame state.

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
| `src/frame.zig` | Pure functions that encode and decode frame headers, resolve canonical lengths into `DecodedHeader`, calculate serialized sizes, mask payloads in place, and validate close payloads. |
| `src/queue.zig` | Implements a generic bounded deque `Queue(Element)` over caller-provided storage; it performs no allocation. |
| `src/event.zig` | Holds the iterative receive/transmit state machine, `ConnConfig`, `FrameNode`, `FragmentState`, and the concrete `FrameQueue` alias for the TX ring buffer. |
| `src/c_api.zig` | Exports the role-aware, bounded C ABI and bridges the `Callbacks` struct and caller-owned `ZslayConn` storage to the Zig state machine. |
| `src/root.zig` | Defines the public Zig module and re-exports the supported API. |
| `src/test.zig` | Tests layouts, queues, frame encoding/decoding, masking, and malformed-input resilience. |
| `src/bench.zig` | Standalone multi-session encode/decode benchmark reporting throughput and sampled latency percentiles; run with `zig build bench` and excluded from the unit test suite. |
| `src/c_api_smoke.c` | C11 ABI smoke test compiled and linked against the installed `zslay.h` and static library; executed by `zig build test`. |

## Build and Environment

| File | Purpose |
| --- | --- |
| `build.zig` | Builds the Zig module and static C library; defines `test`, `bench`, and `check` steps. The `test` step also compiles, links, and runs the C ABI smoke test. |
| `build.zig.zon` | Stores package metadata, the minimum Zig version, and published paths. |
| `include/zslay.h` | Declares the installed C ABI, callback contracts, result codes, storage alignment, and borrowed-memory lifetimes. |
| `flake.nix`, `flake.lock` | Pin the Nix development shell, checks, formatter, and cross-platform release builds. |
| `.envrc` | Loads the Nix flake through direnv. |
| `.pre-commit-config.yaml` | Configures local formatting and validation hooks. |

## Project Support Files

- `README.md` introduces the library and setup.
- `CONTRIBUTE.md` and `CODING_CONVENTION.md` define the contributor workflow and style.
- `SECURITY.md`, `CHANGELOG.md`, and `LICENSE` cover reporting, releases, and licensing.
- `CI_CD_PIPELINE.md` documents CI and publishing; `.github/` contains workflows and community templates.
- `AGENTS.md`, `SKILL.md`, `.agents/`, and `skills-lock.json` contain repository-specific AI agent guidance.
- `AGENT_DIRECTORY.md` maps the specialized sub-agents to owned paths, delegation rules, and skill coverage.
- `.opencode/agents/` holds the sub-agent definitions that opencode discovers for this project.
- `misc/zslay-banner.png` is the README banner asset.
