# zslay - AI Agent System Prompt & Guidelines

This document serves as a persistent context guide for LLMs and AI Agents interacting with the `zslay` repository. When writing code, generating pull requests, or debugging, adhere strictly to the following architectural constraints and design philosophies.

## 1. Project Overview

`zslay` is a pure Zig (version 0.16.0) port of the C-based `wslay` library. It acts as a highly optimized, memory-safe, and I/O-agnostic core for parsing WebSocket (RFC 6455) frames. When replicating logic from the original C codebase, adhere to the `wslay-porting` skill.

**Primary Goals:**
- **Zero-allocation:** No dynamic memory allocation during standard parser execution.
- **Cache-efficient:** Strict adherence to Data-Oriented Design (DOD).
- **I/O-Agnostic:** Pure state machine implementation without touching network sockets.
- **FFI-ready:** Drop-in C ABI compatibility for Node.js, Python, and Rust consumers.

---

## 2. Unbreakable Architectural Rules

When contributing to this codebase, you **MUST** follow these rules without exception:

### Rule 1: Zero-Allocation at Runtime
- **DO NOT** use `std.heap` (like `page_allocator`, `c_allocator`, or `ArenaAllocator`) anywhere in the parser or state machine (`src/frame.zig`, `src/event.zig`).
- **DO** use bounded ring buffers, intrusive linked lists, or pre-allocated static contexts provided by the library consumer.

### Rule 2: I/O Agnosticism
- **DO NOT** import or use `std.net`, `std.posix.read`, `std.posix.write`, or any socket-level APIs in the core library.
- **DO** treat `zslay` as a pure data transformation engine. It receives slices of raw bytes (`[]const u8`), updates its internal state, executes XOR masking, and yields structured events or requires the caller to manage the actual I/O.

### Rule 3: Data-Oriented Design (DOD)
- **DO NOT** nest stateful contexts with arbitrary heap pointers (pointer chasing).
- **DO NOT** use virtual tables (`vtable`) or dynamic dispatch inside parser loops.
- **DO** use explicit, small integers (`u16`, `u32`) as indices for state tracking to maximize CPU L1/L2 cache locality.
- **DO** use `packed struct` for hardware/protocol-mapped memory layouts (e.g., `FrameHeader`).
- **DO** apply the `dod` and `zslay-dod` skills to optimize memory layout, data locality, and throughput.

### Rule 4: FFI Boundary and ABI Stability
When touching `src/c_api.zig` or `src/types.zig`:
- **DO** explicitly define backing integer sizes for enums and structs (e.g., `enum(u4)` or `packed struct(u16)`).
- **DO NOT** pass Zig slices (`[]u8`) directly across FFI boundaries. Always decompose them into a many-item pointer (`[*]u8`) and a length (`usize`).
- **DO** expose stateful contexts as opaque structures (`*anyopaque`).

---

## 3. Environment and Tooling

- **Hermetic Builds:** The development environment is strictly pinned using Nix (`flake.nix`). **DO NOT** suggest or write scripts that install global dependencies via `apt`, `brew`, or `npm`. Apply `nix-best-practices` and `nix-hermetic` skills when modifying Nix workflows.
- **Testing:**
  - Native logic (XOR math, struct layouts) should be tested via `test` blocks in `src/test.zig`.
- **Formatting:** Comply with standard Zig formatting. Run `zig fmt .` before any commits. The CI pipeline enforces rigorous linting.

## 4. Codebase Navigation

- `src/types.zig`: Only passive data structures, layouts, opcodes, and error sets.
- `src/frame.zig`: Stateless, low-level pure functions (encode, decode, mask).
- `src/queue.zig`: Data-oriented, zero-allocation collections (ring buffers).
- `src/event.zig`: High-level connection state machine and callback scheduler.
- `src/c_api.zig`: FFI exports (`export fn`).

## 5. Coding & Workflow Rules

- **Comments:** Use as few comments as possible (maximum 2 lines per comment block). Always use `//` for comments. Do NOT use `///` or block comments (`/* */`).
- **Style:** Follow the Linux coding style convention and Zig best practices.
- **Emojis:** NO EMOJIS are allowed anywhere in this project (code, comments, commits, PRs, etc.).
- **Git Workflow:** Follow the project's Git rules before pushing code to GitHub (see the `github-git` skill).
- **Global Skills:** Refer to `SKILL.md` in the project root for a comprehensive list of all agent skills and behaviors.
