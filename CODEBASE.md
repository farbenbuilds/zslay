# zslay - Codebase Guide

A zero-allocation, I/O-agnostic WebSocket parser written in Zig 0.16.0 (a native port of the wslay C library).
Frontend/Consumers: Zig modules (`build.zig.zon`), C/C++ FFI (`.a`/`.lib`), and TypeScript wrappers (via FFI).
Backend: Pure Zig standard library.
Design philosophy: Data-Oriented Design (DOD), strict memory control, and Linux Kernel coding style.

This document covers the architecture: how the repository is laid out, what the parser depends on, and how the zero-allocation state machine works end to end. For code style see [CODING_CONVENTION.md](CODING_CONVENTION.md); for setup, workflow, and releases see [CONTRIBUTE.md](CONTRIBUTE.md); for CI/CD see [CI_CD_PIPELINE.md](CI_CD_PIPELINE.md).

## Project Structure

```
.github/                  # CI/CD workflows (lint, test, deno-test, publish)
src/                      # Core Zig source code
  root.zig                # Main entry point and C API exports
  types.zig               # Packed structs (FrameHeader) and DOD data layouts
  state.zig               # Finite State Machine (FSM) transitions
  masking.zig             # XOR payload masking/unmasking logic
  test.zig                # Isolated unit tests and layout assertions
tests/                    # Integration testing
  autobahn/               # Deno Autobahn WebSocket compliance test harness
build.zig                 # Zig build script (static lib and module definitions)
build.zig.zon             # Zig package manager manifest
flake.nix                 # Nix cross-compilation environment and outputs

```

## Key Dependencies

Core: Zero external dependencies. Built entirely on the Zig standard library (`std`).
Build/CI: `nix`, `flake-parts`, `zig-overlay` (for reproducible cross-compilation).
Testing: `deno` (for running the Autobahn compliance testsuite via FFI).

## Zero-Allocation Parsing Pipeline

### Data-Oriented Architecture

zslay operates as a pure state machine without owning any memory allocators. It relies on precise hardware memory layouts to parse RFC 6455 WebSocket frames efficiently:

- `FrameHeader` -- A `packed struct` guaranteeing exact bit-width mapping to the network protocol (FIN, RSV1-3, Opcode, Mask, Payload Length).
- `ParserState` -- A flat enum tracking the exact byte boundary of the current frame.

All state structures are designed as flat, contiguous blocks of memory, avoiding pointer chasing and deep nesting.

### I/O-Agnostic Design Flow

Like the original wslay C library, zslay does not read from or write to network sockets directly. The consumer (e.g., `uWebZockets`) handles I/O and passes raw byte slices to the parser.

1. Consumer reads `[]const u8` from the network socket.
2. Consumer passes the slice into the zslay state machine.
3. zslay updates its internal finite state machine byte-by-byte or chunk-by-chunk.
4. When a frame header is resolved, zslay extracts the payload length and masking key.
5. zslay applies XOR masking in-place or to a provided out-buffer.
6. zslay invokes configured callbacks (or returns state structures) back to the consumer for control frames (PING/PONG/CLOSE) or message fragments.

### C ABI / FFI Boundary

To serve as a universal backend for Node.js, Deno, Rust, or C++, zslay exposes a strict C ABI:

- Primitive types only (`usize`, `*c_void`, `u8`).
- Stateful contexts are passed as opaque pointers.
- Arrays and buffers are passed as strict pointer and length pairs.

### Compliance Testing Flow

1. `zig build test` asserts internal memory invariants directly in `src/test.zig` (e.g., verifying `FrameHeader` memory footprint matches the specification exactly).
2. The Deno test harness loads the compiled static library or shared object via FFI.
3. Deno spins up an Autobahn test server/client.
4. Fuzzing payloads are fed through the C ABI to validate fragmentation, UTF-8 bounds, and control code handling against RFC 6455 edge cases without triggering memory corruption or panics.
