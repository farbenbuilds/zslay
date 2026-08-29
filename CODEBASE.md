# Codebase Map

`zslay` is a zero-allocation, I/O-agnostic WebSocket framing library written in Zig 0.16.0. Callers own buffers and network I/O; the library parses, serializes, masks, and tracks frame state.

## Runtime Flow

Incoming bytes move through `event.Conn`, which collects a header, delegates validation and decoding to `frame.zig`, and returns an `RxAction` telling the caller what to provide or consume next. Outgoing frames are prepared by `event.Conn`, stored in the caller-backed queue, and exposed through `TxAction`. `c_api.zig` adapts this flow to C callbacks and opaque pointers.

## Source Files

| File | Purpose |
| --- | --- |
| `src/types.zig` | Defines RFC 6455 opcodes, close codes, parser errors, packed frame headers, and masking keys. |
| `src/frame.zig` | Encodes and decodes frame headers, calculates serialized sizes, and masks payloads in place. |
| `src/queue.zig` | Implements a generic bounded deque over caller-provided storage; it performs no allocation. |
| `src/event.zig` | Holds the receive/transmit state machine, connection context, outgoing frame nodes, and static actions. |
| `src/c_api.zig` | Exports the C ABI and bridges C callbacks and caller-owned memory to the Zig state machine. |
| `src/root.zig` | Defines the public Zig module and re-exports the supported API. |
| `src/test.zig` | Tests layouts, queues, frame encoding/decoding, masking, throughput, and malformed-input resilience. |

## Build and Environment

| File | Purpose |
| --- | --- |
| `build.zig` | Builds the Zig module and static C library; defines `test` and `check` steps. |
| `build.zig.zon` | Stores package metadata, the minimum Zig version, and published paths. |
| `flake.nix`, `flake.lock` | Pin the Nix development shell, checks, formatter, and cross-platform release builds. |
| `.envrc` | Loads the Nix flake through direnv. |
| `.pre-commit-config.yaml` | Configures local formatting and validation hooks. |

## Project Support Files

- `README.md` introduces the library and setup.
- `CONTRIBUTE.md` and `CODING_CONVENTION.md` define the contributor workflow and style.
- `SECURITY.md`, `CHANGELOG.md`, and `LICENSE` cover reporting, releases, and licensing.
- `CI_CD_PIPELINE.md` documents CI and publishing; `.github/` contains workflows and community templates.
- `AGENTS.md`, `SKILL.md`, `.agents/`, and `skills-lock.json` contain repository-specific AI agent guidance.
- `misc/zslay-banner.png` is the README banner asset.
