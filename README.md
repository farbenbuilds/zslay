<div align="center">
  <img src="misc/zslay-banner.png" alt="zslay banner" />
</div>

# zslay - Zero-allocation, I/O-agnostic WebSocket framing library

`zslay` is a pure Zig (0.16.0) port of the C-based `wslay` library. It acts as a highly optimized, memory-safe, and I/O-agnostic core for parsing WebSocket (RFC 6455) frames.

## Why Zig 0.16.0?

Zig 0.16.0 brings a suite of powerful features perfectly suited for systems-level parsers:
- **Zero Hidden Control Flow:** Predictable performance with no hidden allocations or exceptions.
- **Memory Safety:** Built-in spatial safety and compile-time checks catch bounds and alignment errors early.
- **Fast Compilation & FFI:** Drop-in C ABI compatibility natively without overhead. It smoothly integrates with Node.js, Python, Rust, and others via C FFI.
- **Modern standard library:** Embraces the modern `std.io` architecture while avoiding deprecated builtins, ensuring long-term stability.

## Data-Oriented Design (DOD)

This project strictly adheres to Data-Oriented Design principles to squeeze out maximum performance:
- **Zero-Allocation:** No dynamic memory allocation during standard parser execution. `zslay` utilizes bounded ring buffers and pre-allocated static contexts instead of heap allocators.
- **Cache-Efficient:** Eliminates pointer chasing. We use explicit, small integers (`u16`, `u32`) as indices for state tracking to maximize CPU L1/L2 cache locality.
- **Flat Layouts:** Heavy usage of `packed struct` mapped directly to hardware/protocol byte boundaries (e.g., `FrameHeader`).

## Functional Core, Imperative Shell

The core is organized as pure functions around explicit state:
- **Pure Transformations:** Encoding, decoding, length resolution, and XOR masking are stateless functions over caller-owned buffers with explicit error sets.
- **Explicit State:** The only mutable state lives in the caller-provided connection context and bounded queue. No globals, no hidden mutation, no dynamic dispatch.
- **Iterative Control Flow:** The RX/TX state machines use early returns and flat loops instead of recursion, keeping stack usage constant.
- **No Silent Fallbacks:** Invalid protocol input returns a typed error instead of a substituted default.

## Readable Type Model

Every public type is top-level, explicitly named, and free of nested or inferred type machinery:

- `ConnConfig` and `FrameNode` describe connection inputs and outgoing frames without nesting inside `Conn`.
- `DecodedHeader`, `FrameHeader`, and `MaskingKey` model wire data with fixed, protocol-defined widths.
- `FrameHeaderBuffer`, `MaxFrameHeaderLen`, and `MaskingKeyLen` replace magic numbers in buffer sizing.
- `FrameQueue` names the concrete bounded queue used by `Conn`, while `Queue(Element)` remains available for other element types.
- `RxAction`, `TxAction`, and `RxState` stay flat `u8`-backed enums driven by `switch`, never vtables.

Length fields use `_len` for byte counts and `_sent` for stream progress, so a field name alone tells you what it holds.

## An Improved RFC6455 Implementation

`zslay` is not just a port; it's an enhancement over traditional implementations:
- **Purely I/O-Agnostic:** It treats parsing as a pure data transformation engine. `zslay` does not touch network sockets. You feed it slices of raw bytes, and it yields structured events.
- **Memory Predictability:** By keeping state management outside the library and avoiding heap allocations entirely, `zslay` is completely deterministic in its memory usage.
- **Secure by Default:** Distributed artifacts are built with `ReleaseSafe`, so bounds-checking and the other safety checks remain enabled in release binaries. Malformed or malicious WebSocket payloads are rejected with typed errors.

## Getting Started

Development is strictly pinned using Nix to guarantee bit-for-bit reproducibility across all OS platforms. No global dependencies (like apt, brew, or npm) are required.

### Prerequisites
- Install Nix.
- Enable Nix Flakes.
- (Optional but recommended) Install direnv.

### Clone, Dev, and Build

**1. Clone the repository**
```bash
git clone https://github.com/farbenbuilds/zslay.git
cd zslay
```

**2. Enter the hermetic Nix environment**
*(Provides Zig 0.16.0 and all necessary tooling)*
```bash
nix develop
```
*Or, if you use direnv:*
```bash
direnv allow
```

**3. Install pre-commit hooks (Optional but recommended)**
```bash
pre-commit install
```

**4. Run native tests**
```bash
zig build test
```
*This also compiles, links, and runs the C11 ABI smoke test (`src/c_api_smoke.c`) against the installed `zslay.h` and static library.*

**5. Run the benchmark**
```bash
zig build bench
```

**6. Format the code**
```bash
zig fmt .
```

### C API

Native Zig callers initialize `Conn` with a `ConnConfig` containing the endpoint role and frame/message limits. The static library installs `zslay.h`; C callers allocate connection and frame-node storage using the reported size and alignment, then provide the same mandatory configuration.

`zslay_conn_recv` performs one bounded unit of work and returns `ZSLAY_PROGRESS` when the caller should invoke it again. Payload callbacks are streaming chunks: use `payload_offset`, `frame_len`, and `end_of_frame` for boundaries; the WebSocket `fin` bit describes message fragmentation only.

`zslay_conn_reset` abandons partial receive state, including an active fragmented message, without touching the transport. It returns `ZSLAY_ERR_INVALID_ARGUMENT` for a null or misaligned handle.

Client connections must provide a cryptographically secure mask callback that fills all four requested bytes and returns zero. Queued transmit payloads remain borrowed until sending completes, and receive chunk pointers expire when the callback returns.

Application-layer close validation is available to Zig callers through `validate_close_payload(payload)`: an empty payload is valid, a one-byte payload is rejected, the close code must be 1000-1003, 1007-1014, or 3000-4999, and the reason must be valid UTF-8.

## AI Agent Workflows

Repository-specific sub-agents live in `.opencode/agents/`, covering the parser, event loop, C ABI, Node-API bindings, tests, review, release, and documentation. Each agent loads local skills from `.agents/skills/` and verifies changes with `zig build test` and `zig fmt --check .`. The roster, ownership map, and skill coverage are documented in [AGENT_DIRECTORY.md](AGENT_DIRECTORY.md).

## Credits

`zslay` is heavily inspired by and ported from the original C WebSocket library, [wslay](https://github.com/tatsuhiro-t/wslay), created by Tatsuhiro Tsujikawa. We extend our gratitude for their foundational work.

## uWebZockets

`zslay` is designed to be the foundational core of **[uWebZockets](https://github.com/farbenbuilds/uWebZockets)**, an implementation of the highly acclaimed `uWebSockets` library, fully written in pure Zig.
uWebZockets brings industry-leading concurrency and throughput to the Zig ecosystem, leveraging `zslay`'s zero-allocation protocol parsing at its heart.
