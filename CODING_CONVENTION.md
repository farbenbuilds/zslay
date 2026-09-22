# zslay - Coding Conventions

Code style standards for the `zslay` project using the Zig 0.16.0 toolchain.

The `zslay` codebase strictly enforces the **Linux Kernel Coding Style** adapted for Zig. To maintain zero-allocation guarantees, C-ABI compatibility, and Linux Kernel-style C-portability, all pull requests must adhere to the rules below.

For architecture see [CODEBASE.md](CODEBASE.md); for setup, workflows, and releases see [CONTRIBUTE.md](CONTRIBUTE.md).

---

## 1. Code Style - Zig Core & Linux Kernel

### Formatting

- **Indentation**: Follow the standard `zig fmt` formatting rules (4 spaces).
- **Line Length**: Maximum 120 characters per line.
- **Brace Placement**: Follow the standard `zig fmt` rules for all brace placements.

### File Naming

- **`snake_case`** for all `.zig` and `.zon` files (e.g., `frame_header.zig`, `state_machine.zig`).
- `root.zig` is the Zig module entry point; C FFI exports live in `src/c_api.zig`.

### Type Definitions & Data-Oriented Design (DOD)

- **PascalCase** for type names (e.g., `FrameHeader`, `ParserState`).
- Define public types at file scope with explicit names; do not nest types inside containers.
- Extract repeated or inline type expressions into named aliases (for example `FrameHeaderBuffer`, `FrameQueue`, or C callback typedefs).
- Name byte counts with `_len` and stream progress with `_sent` (for example `payload_len`, `header_sent`) instead of ambiguous names such as `extended_len`.
- Use `packed struct` for precise hardware and network protocol layouts (e.g., WebSocket frame headers) to guarantee exact bit-widths and zero padding.
- Use `extern struct` for types that cross the C FFI boundary.
- Group data by access patterns (prefer Struct of Arrays over Array of Structs when processing bulk payloads).
- Favor flat data structures. Avoid deep nesting.

### Naming Conventions

- **Variables and functions**: `snake_case` (Linux Kernel style).
- **Type-level constants and standard globals**: `PascalCase` (Zig standard).
- **File-level scoped private variables**: prefix with underscore `_var_name` (rarely used).
- **C FFI exported functions**: prefix with `zslay_` (e.g., `zslay_frame_parse`).

---

## 2. Linux Kernel Control Flow

- **Early Returns (Guard Clauses)**: Handle errors first and return early to keep the "happy path" flat.
- **Flat Nesting**: Avoid deep `if/else` blocks. Maximum 2 levels of indentation within a function body.
- **Iteration over Recursion**: Parser and state machine loops must be iterative with early returns. Recursion is prohibited in parser paths.
- **Error Handling**: Use Zig's `error` sets and `!`. **Never use `catch unreachable`** unless the condition is mathematically proven impossible.
- **Resource Cleanup**: Use Zig's `defer` and `errdefer` in place of the traditional Linux Kernel `goto error_out` labels. This guarantees cleanup on scope exit without spaghetti control flow.

---

## 3. Functional Programming

- **Pure Core**: Functions in `src/frame.zig` and pure helpers must not mutate external state or capture hidden globals. The same input must yield the same output, and writes go only into caller-owned buffers.
- **Explicit State**: All mutable state lives in caller-provided contexts (`src/queue.zig`, `src/event.Conn`). Module-level mutable variables are prohibited.
- **No Object-Oriented Constructs**: No inheritance, no vtables, no dynamic dispatch, no hidden receiver state. Zig methods are allowed only as thin, explicit transitions over caller-owned contexts. C callback typedefs at the FFI boundary are the sole exception; see Section 6.
- **Typed Failures**: Public functions declare explicit error sets. Silent fallbacks (zero keys, truncation, default substitution) are prohibited.
- **Deterministic Control Flow**: Prefer `switch` over non-exhaustive enums, early returns, and flat loops.

---

## 4. Memory and Allocations

- **Zero-Allocation**: No hidden allocations. The parser must remain completely detached from memory allocators (`std.mem.Allocator`).
- **I/O Agnostic**: The parser only operates on user-provided slices (`[]u8` or `[]const u8`). It reads and updates state, leaving actual I/O execution (such as using `std.Io` in Zig 0.16.0) and memory management entirely to the caller.
- **Large Structures**: Pass large structures by constant pointer (`*const T`) to avoid unnecessary stack copying.

---

## 5. Import Order and C ABI Boundaries

- **Import Order**:
  1. Standard library (`const std = @import("std");`).
  2. Blank line.
  3. Internal module imports (`const types = @import("types.zig");`).
- Keep `usingnamespace` restricted to FFI boundary files; never use it in core logic.

### Exporting

- Annotate functions intended for the static library (`.a` / `.lib`) or dynamic library with `export`.
- Use standard C types (`c_int`, `usize`, `*c_void`) at the API boundary to guarantee FFI safety for Node.js, Deno, and Rust consumers.

---

## 6. Comments, Documentation & Restrictions

### Comments

- **Self-documenting code**: Do not add inline comments (`//`) explaining logic inside function bodies. The code logic, variable names, and explicit types (`packed struct`, precise bit-widths) must be entirely self-documenting.
- **No Doc-strings**: `///` doc comments and block comments (`/* */`) are not used in this project. Always use `//`, and only where a short note is genuinely required (maximum 2 lines per comment block).
- **Explicit Types**: Public functions declare explicit parameter, return, and error-set types; do not rely on inferred error sets or implicit coercions at API boundaries.

### Emojis

- **No emojis**: Never use emoji characters in `.md` files, commit messages, error logs, or anywhere else in the codebase.

### Restricted Patterns

- `std.debug.print`: **Off** (only allowed in local `test` blocks, never in production code).
- **Dynamic dispatch (Vtables / Function Pointers)**: **Off**. To route logic dynamically, explicitly use `switch` statements over enums (e.g., `ParserState`) to maintain strict static dispatch and optimize branch prediction. _(Note: The builtin `@fieldParentPtr` is allowed because it is a static, compile-time O(1) pointer offset calculation, not a runtime dynamic dispatch)._ C callback typedefs at the FFI boundary (`src/c_api.zig`, `include/zslay.h`) are the documented exception: they are function pointers required by the C ABI, never used to dispatch core parser paths, which stay `switch`-based.

---

## 7. Code Snippet Example

```zig
const std = @import("std");

// WsFrameHeader contains the basic header information of a WebSocket frame.
pub const WsFrameHeader = packed struct(u16) {
    fin: bool,
    reserved: u3,
    opcode: u4,
    mask: bool,
    payload_length: u7,
};

// zslay_parse_frame_header parses the input byte buffer to extract header information.
pub export fn zslay_parse_frame_header(buffer_ptr: [*]const u8, len: usize) c_int {
    if (len < 2) return -1;

    const buffer = buffer_ptr[0..len];
    const header_int = std.mem.readInt(u16, buffer[0..2][0..2], .little);
    const header: WsFrameHeader = @bitCast(header_int);

    switch (header.opcode) {
        1, 2 => return 0,
        else => return -2,
    }
}
```
