# zslay - Coding Conventions

Code style standards for the Zig 0.16.0 codebase. Most formatting is strictly enforced by `zig fmt`; the rest are architectural conventions that reviewers hold the line on to maintain zero-allocation guarantees, C-ABI compatibility, and Linux Kernel-style C-portability. For architecture see [CODEBASE.md](CODEBASE.md); for setup, workflows, and releases see [CONTRIBUTE.md](CONTRIBUTE.md).

## Code Style - Zig Core

### Formatting (enforced by `zig fmt`)

- 4 spaces indent.
- Max 120 characters per line.
- Commas at the end of multi-line structures and function arguments to force vertical formatting.

### File Naming

- **snake_case** for all `.zig` and `.zon` files (e.g., `frame_header.zig`, `state_machine.zig`).
- `root.zig` serves as the primary entry point for the Zig module and C FFI exports.

### Type Definitions & Data-Oriented Design

- **PascalCase** for type names: `FrameHeader`, `ParserState`.
- Use `packed struct` for precise hardware and network protocol layouts (e.g., WebSocket frame headers) to guarantee exact bit-widths and zero padding.
- Use `extern struct` for types that cross the C FFI boundary.
- Group data by access patterns (Struct of Arrays over Array of Structs when processing bulk payloads).
- Favor flat data structures. Avoid deep nesting.

### Naming Conventions

- Variables and functions: `snake_case` (Linux Kernel style).
- Type-level constants and standard globals: `PascalCase` (Zig standard).
- File-level scoped private variables: prefix with underscore `_var_name` (rarely used).
- C FFI exported functions: prefix with `zslay_` (e.g., `zslay_frame_parse`).

### Linux Kernel Control Flow (mandatory)

- **Early Returns (Guard Clauses):** Handle errors first and return early to keep the "happy path" flat.
- **Flat Nesting:** Avoid deep `if/else` blocks. Maximum 2 levels of indentation within a function body.
- **Error Handling:** Use Zig's `error` sets and `!`. Never use `catch unreachable` unless the condition is mathematically proven impossible.
- **Resource Cleanup:** Use Zig's `defer` and `errdefer` in place of Linux Kernel `goto error_out` labels. This guarantees cleanup on scope exit without the spaghetti control flow.

### Memory and Allocations (Zero-Allocation)

- **No hidden allocations.** The parser must remain completely detached from memory allocators (`std.mem.Allocator`).
- **I/O Agnostic:** The parser only operates on user-provided slices (`[]u8` or `[]const u8`). It reads and updates state, leaving I/O and memory management entirely to the caller.
- Pass large structures by constant pointer (`*const T`) to avoid unnecessary stack copying.

### Import Order

1. Standard library (`const std = @import("std");`).
2. Blank line.
3. Internal module imports (`const types = @import("types.zig");`).
4. Keep `usingnamespace` restricted to FFI boundary files, never in core logic.

### Exporting and C ABI Boundaries

- Annotate functions intended for the static library (`.a` / `.lib`) with `export`.
- Use standard C types (`c_int`, `usize`, `*c_void`) at the API boundary to guarantee FFI safety for Node.js, Deno, and Rust consumers.

### Comments and Emojis

- **No comments in code.** Do not add inline comments, block comments, or doc-strings to the `.zig` files. The code, variable names, and explicit types (`packed struct`, precise bit-widths) must be entirely self-documenting.
- **No emojis in markdown or code.** Never use emoji characters in `.md` files, commit messages, error logs, or anywhere else in the codebase.

### Restricted Patterns

- `std.debug.print`: Error (only allowed in local `test` blocks, never in production code).
- Dynamic dispatch (`@fieldParentPtr` / interfaces): Off (use explicit `switch` statements over enums for parser states to maintain strict branch prediction).
