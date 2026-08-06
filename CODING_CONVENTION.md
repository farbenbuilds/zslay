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
- `root.zig` serves as the primary entry point for the Zig module and C FFI exports.

### Type Definitions & Data-Oriented Design (DOD)

- **PascalCase** for type names (e.g., `FrameHeader`, `ParserState`).
- Use `packed struct` for precise hardware and network protocol layouts (e.g., WebSocket frame headers) to guarantee exact bit-widths and zero padding.
- Use `extern struct` for types that cross the C FFI boundary.
- Group data by access patterns (prefer Struct of Arrays over Array of Structs when processing bulk payloads).
- Favor flat data structures. Avoid deep nesting.

### Naming Conventions

- **Variables and functions**: `snake_case` (Linux Kernel style) [6, 7].
- **Type-level constants and standard globals**: `PascalCase` (Zig standard).
- **File-level scoped private variables**: prefix with underscore `_var_name` (rarely used).
- **C FFI exported functions**: prefix with `zslay_` (e.g., `zslay_frame_parse`).

---

## 2. Linux Kernel Control Flow

- **Early Returns (Guard Clauses)**: Handle errors first and return early to keep the "happy path" flat.
- **Flat Nesting**: Avoid deep `if/else` blocks. Maximum 2 levels of indentation within a function body.
- **Error Handling**: Use Zig's `error` sets and `!`. **Never use `catch unreachable`** unless the condition is mathematically proven impossible.
- **Resource Cleanup**: Use Zig's `defer` and `errdefer` in place of the traditional Linux Kernel `goto error_out` labels [8]. This guarantees cleanup on scope exit without spaghetti control flow.

---

## 3. Memory and Allocations

- **Zero-Allocation**: No hidden allocations. The parser must remain completely detached from memory allocators (`std.mem.Allocator`).
- **I/O Agnostic**: The parser only operates on user-provided slices (`[]u8` or `[]const u8`). It reads and updates state, leaving actual I/O execution (such as using `std.Io` in Zig 0.16.0 [4]) and memory management entirely to the caller.
- **Large Structures**: Pass large structures by constant pointer (`*const T`) to avoid unnecessary stack copying.

---

## 4. Import Order and C ABI Boundaries

- **Import Order**:
  1. Standard library (`const std = @import("std");`).
  2. Blank line.
  3. Internal module imports (`const types = @import("types.zig");`).
- Keep `usingnamespace` restricted to FFI boundary files; never use it in core logic.

### Exporting

- Annotate functions intended for the static library (`.a` / `.lib`) or dynamic library with `export`.
- Use standard C types (`c_int`, `usize`, `*c_void`) at the API boundary to guarantee FFI safety for Node.js, Deno, and Rust consumers.

---

## 5. Comments, Documentation & Restrictions

### Comments

- **Self-documenting code**: Do not add inline comments (`//`) explaining logic inside function bodies. The code logic, variable names, and explicit types (`packed struct`, precise bit-widths) must be entirely self-documenting.
- **Doc-strings**: **Only use `///` (doc comments) for functions and structures marked as `export` or `pub`**. This is mandatory so the Zig compiler can automatically generate documentation via the `-femit-docs` flag for API consumers.

### Emojis

- **No emojis**: Never use emoji characters in `.md` files, commit messages, error logs, or anywhere else in the codebase.

### Restricted Patterns

- `std.debug.print`: **Off** (only allowed in local `test` blocks, never in production code).
- **Dynamic dispatch (Vtables / Function Pointers)**: **Off**. To route logic dynamically, explicitly use `switch` statements over enums (e.g., `ParserState`) to maintain strict static dispatch and optimize branch prediction. _(Note: The builtin `@fieldParentPtr` is allowed because it is a static, compile-time O(1) pointer offset calculation, not a runtime dynamic dispatch)._

---

## 6. Code Snippet Example

```zig
const std = @import("std");

/// WsFrameHeader - Contains the basic header information of a WebSocket frame.
/// This structure crosses the FFI boundary and uses explicit static typing.
pub const WsFrameHeader = packed struct(u16) {
    fin: bool,
    reserved: u3,
    opcode: u4,
    mask: bool,
    payload_length: u7,
};

/// zslay_parse_frame_header - Parses the input byte buffer to extract header information.
pub export fn zslay_parse_frame_header(buffer_ptr: [*]const u8, len: usize) c_int {
    const buffer = buffer_ptr[0..len];

    if (buffer.len < 2) {
        return -1;
    }

    // All parsing operations must be zero-allocation
    var header: WsFrameHeader = undefined;
    header.fin = (buffer[0] & 0x80) != 0;
    header.opcode = @as(u4, @truncate(buffer[0] & 0x0F));

    // Always use static dispatch (switch) instead of function pointers
    switch (header.opcode) {
        1, 2 => {
            return 0;
        },
        else => {
            return -2;
        },
    }
}
```
