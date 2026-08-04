# zslay - Codebase Architecture

`zslay` is a pure, zero-allocation, I/O-agnostic WebSocket protocol parser written in Zig 0.16.0, ported from the C-based `wslay` library. The project leverages Data-Oriented Design (DOD) to guarantee highly optimized CPU cache usage and flat memory layouts.

---

## Codebase Directory Structure

The repository is organized into distinct files, separating contiguous data layouts from stateful pipelines to prevent pointer chasing and ensure acyclic compilation dependencies.

| C File (wslay)            | Zig File (zslay) | Architecture & Architectural Role (DOD / Zero-Allocation)                                                                                                                                                |
| :------------------------ | :--------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `wslay.h` / `wslay_net.h` | `src/types.zig`  | **Data Types**: Contains packed structs (e.g., `FrameHeader`), non-exhaustive enums (Opcodes, Status Codes), and error sets with explicit backing integers. Separates data layout from behavioral logic. |
| `wslay_frame.c` / `.h`    | `src/frame.zig`  | **Low-Level Parser**: Implements stateless, pure functions to encode/decode raw frames and perform optimized XOR masking on contiguous byte buffers. Entirely I/O-agnostic.                              |
| `wslay_queue.c` / `.h`    | `src/queue.zig`  | **Data-Oriented Queue**: Implements zero-allocation bounded ring buffers or intrusive linked lists, avoiding any heap allocations or dynamic nodes.                                                      |
| `wslay_event.c` / `.h`    | `src/event.zig`  | **State Machine & High-Level API**: Manages high-level connection lifecycles and schedules callbacks. Operates strictly on pre-allocated static contexts.                                                |
| _(None - C Native)_       | `src/c_api.zig`  | **C Compatibility Layer**: Exposes C-ABI compatible FFI wrappers (`export fn`) using primitive types, many-item pointers, and opaque contexts for Node.js, Deno, and Rust consumers.                     |
| _(None)_                  | `src/main.zig`   | **Root Module**: Serves as the primary entry point for the Zig package system, packaging and exporting modules for domestic Zig package manager consumers.                                               |
| `tests/` (CUnit)          | `src/test.zig`   | **Native Unit Tests**: Contains Zig-native `test` blocks asserting struct alignments, bit-width mapping, XOR masking math, and state machine invariants.                                                 |

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

## Testing & Verification Flow

Reliability and protocol compliance are enforced through a layered testing strategy:

### 1. Zig Unit Tests (`src/test.zig`)

The native test suite in `src/test.zig` is compiled and run via `zig build test`. It directly verifies:

- Physical memory footprint and alignment of packed structures (e.g., verifying `@bitSizeOf(FrameHeader) == 16`).
- Mathematical correctness of the XOR masking implementation.
- Edge cases of the event queue and bounded ring buffers.
- State transition validation under invalid protocol payloads.

### 2. Integration & Compliance Testing (Deno & Autobahn)

For FFI and RFC 6455 compliance:

- The Deno test harness loads the compiled static library (`.a` / `.lib`) or shared object using the C-ABI.
- Deno drives an Autobahn test client/server, executing fuzzing payloads through the FFI boundaries.
- This verifies parsing resilience against malformed frames, UTF-8 boundaries, and invalid control codes without memory corruption or run-time panics.

### 3. Automated Workflows (`.github/workflows/`)

GitHub Actions automatically execute on every push and pull request to maintain codebase health, enforce strict performance invariants, and verify FFI boundary safety:

- **`lint.yml` (Code Style & Formatting)**: Enforces the project's custom Linux Kernel Coding Style. Since `zslay` rejects standard `zig fmt` (which forces a 4-space indent) in favor of 1 Tab (8-space) indentation, this workflow utilizes custom scripting or `editorconfig-checker` to validate proper tab-indentation, prevent trailing whitespaces, and verify the 120-character line limit.
- **`test.yml` (Native Zig Unit Testing)**: Compiles and executes the native unit test suite located in `src/test.zig` on every push and pull request. It cross-compiles against Tier 1 and Tier 2 targets (e.g., `x86_64-linux`, `aarch64-macos`, `x86_64-windows`) to assert struct alignments, physical memory layouts (such as `@bitSizeOf(FrameHeader) == 16`), and verify that zero-allocation guarantees are fully preserved.
- **`deno-test.yml` (Deno-FFI & Autobahn Compliance)**: Asserts the safety and correctness of the C-ABI boundaries. It compiles `zslay` into a static/shared library, dynamically loads it into the Deno runtime via FFI, and executes integration tests. Deno drives an Autobahn Testsuite harness, feeding raw fuzzing payloads through the FFI boundary to validate UTF-8 validation, fragmentation logic, and control code handling without causing memory leaks or runtime panics.
- **`publish.yml` (Release Packaging & Distribution)**: Automates the production build and deployment pipeline whenever a new Git release tag (e.g., `v1.0.0`) is pushed. It cross-compiles optimized static libraries (`.a` / `.lib`) and shared objects for all targeted platforms, generates the corresponding C header files, packages the Zig module, and publishes the compiled assets directly to GitHub Releases.
