# zslay - Codebase Architecture

`zslay` is a pure, zero-allocation, I/O-agnostic WebSocket protocol parser written in Zig 0.16.0, ported from the C-based `wslay` library. The project leverages Data-Oriented Design (DOD) to guarantee highly optimized CPU cache usage and flat memory layouts.

---

## Codebase Directory Structure

The repository is organized into distinct files, separating contiguous data layouts from stateful pipelines to prevent pointer chasing and ensure acyclic compilation dependencies.

| C File (wslay)            | Zig File (zslay)     | Architecture & Architectural Role (DOD / Zero-Allocation)                                                                                                                                                |
| :------------------------ | :------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `wslay.h` / `wslay_net.h` | `src/types.zig`      | **Data Types**: Contains packed structs (e.g., `FrameHeader`), non-exhaustive enums (Opcodes, Status Codes), and error sets with explicit backing integers. Separates data layout from behavioral logic. |
| `wslay_frame.c` / `.h`    | `src/frame.zig`      | **Low-Level Parser**: Implements stateless, pure functions to encode/decode raw frames and perform optimized XOR masking on contiguous byte buffers. Entirely I/O-agnostic.                              |
| `wslay_queue.c` / `.h`    | `src/queue.zig`      | **Data-Oriented Queue**: Implements zero-allocation bounded ring buffers or intrusive linked lists, avoiding any heap allocations or dynamic nodes.                                                      |
| `wslay_event.c` / `.h`    | `src/event.zig`      | **State Machine & High-Level API**: Manages high-level connection lifecycles and schedules callbacks. Operates strictly on pre-allocated static contexts.                                                |
| _(None - C Native)_       | `src/c_api.zig`      | **C Compatibility Layer**: Exposes C-ABI compatible FFI wrappers (`export fn`) using primitive types, many-item pointers, and opaque contexts for Node.js, Deno, and Rust consumers.                     |
| _(None)_                  | `src/main.zig`       | **Root Module**: Serves as the primary entry point for the Zig package system, packaging and exporting modules for domestic Zig package manager consumers.                                               |
| `tests/` (CUnit)          | `src/test.zig`       | **Native Unit Tests**: Contains Zig-native `test` blocks asserting struct alignments, bit-width mapping, XOR masking math, and state machine invariants.                                                 |
| `.github/workflows`       | `.github/workflows/` | **CI/CD Pipelines**: Contains GitHub Actions workflows for automated code linting, native Zig testing, Deno-FFI compliance verification, and package publishing.                                         |
| _(None)_                  | `flake.nix`          | **Nix Development Environment**: Declares the reproducible development environment, pinning the exact Zig 0.16.0 compiler, Deno, and necessary development tools.                                        |
| _(None)_                  | `flake.lock`         | **Nix Lockfile**: Stores exact hashes and revisions of Nix dependency inputs to guarantee bit-for-bit reproducibility across all environments.                                                           |
| _(None)_                  | `.envrc`             | **Direnv Shell Trigger**: Integrates with `direnv` to automatically load the Nix development environment (`use flake`) upon entering the workspace directory.                                            |

---

## Core Architectural Decisions

### Data-Oriented Design (DOD)

All structures are modeled as flat, contiguous blocks of memory.

- **No Pointer Chasing**: We avoid nesting structures via heap pointers.
- **Index over Pointer**: Internal relationships and states are tracked using small, explicit integer indices (`u16`/`u32`) rather than 64-bit virtual memory addresses, significantly decreasing the memory footprint and maximizing CPU L1/L2 cache line density.
- **Static Dispatch**: We prohibit virtual tables (vtables) and dynamic dispatch in parser loops, preferring compile-time `switch` blocks on non-exhaustive enums to maximize branch prediction accuracy.

### I/O-Agnostic Design Flow

`zslay` does not own sockets or execute system-level read/write operations. It behaves as a pure state engine:

1. The consumer reads raw bytes from the network socket into a buffer.
2. The consumer feeds the slice to `zslay`'s parser.
3. `zslay` processes the bytes, updates its internal state machine, and applies masking.
4. `zslay` returns structured frame metadata or invokes pre-registered callbacks.

### C ABI / FFI Boundary

To integrate seamlessly with external runtimes (such as Deno, Rust, or Node.js), `src/c_api.zig` enforces strict C-ABI compliance:

- Explicit backing types are declared on all FFI-facing enums and packed structs.
- Stateful contexts are stored in opaque structures and passed as `*anyopaque` pointers.
- Slices (`[]u8`) are unpacked into pairs of many-item pointers (`[*]u8`) and lengths (`usize`).

---

## Testing, Verification & CI/CD Flow

Reliability, style compliance, and protocol correctness are enforced automatically through a layered testing strategy driven by the Nix package manager and automated continuous integration.

### 1. Nix-Powered Local Environment

To guarantee hermetic and reproducible builds, all development, testing, and distribution workflows are executed inside a pinned Nix shell environment (`flake.nix` with `direnv`). This eliminates the "works on my machine" problem by ensuring every developer and CI runner uses the exact same Zig 0.16.0 compiler, Deno runtime, and test dependencies.

### 2. Zig Unit Tests (`src/test.zig`)

The native unit test suite is executed within the Nix environment via `nix develop --command zig build test`. It directly asserts:

- Physical memory footprint and alignment of packed structures (e.g., verifying `@bitSizeOf(FrameHeader) == 16`).
- Mathematical correctness of the XOR masking implementation.
- Edge cases of the event queue and bounded ring buffers.
- State transition validation under invalid protocol payloads.

### 3. Deno & Autobahn Compliance Testing

For FFI boundary and RFC 6455 compliance, we leverage Nix to orchestrate a complete Autobahn test harness without requiring manual global software installations:

- The Deno test harness loads the compiled C-ABI library (`.a` / `.so`) within a Nix shell containing the precise Deno version.
- Nix provisions the necessary testing dependencies (including Deno, Python, and the Autobahn Testsuite CLI).
- Fuzzing payloads are fed through the FFI boundary to validate UTF-8 validation, fragmentation logic, and control code handling against RFC 6455 edge cases without triggering memory corruption or panics.

### 4. Automated Workflows (`.github/workflows/`)

GitHub Actions automatically spin up a Nix environment on every push and pull request to execute the pipeline:

- **`lint.yml` (Code Style & Formatting)**: Uses Nix-cached linters to enforce the project's 1 Tab (8-space) indentation, line limits, and trailing whitespace rules.
- **`test.yml` (Native Zig Unit Testing)**: Installs Nix, restores cached builds, and executes cross-platform unit tests (`zig build test`) across multiple targets.
- **`deno-test.yml` (Deno-FFI & Autobahn Compliance)**: Spins up the Deno/Autobahn environment via Nix, compiles the FFI module, and runs the entire compliance suite.
- **`publish.yml` (Release Packaging & Distribution)**: Triggered by release tags. It uses Nix to cross-compile production-optimized static libraries (`.a` / `.lib`) and shared objects, generates C headers, and uploads assets directly to GitHub Releases.
