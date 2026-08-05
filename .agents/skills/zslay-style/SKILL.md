---
name: zslay-style
description: >
  Linux Kernel Zig Style coding conventions for the zslay project.
  Use when writing, formatting, or refactoring code.
---

# zslay - Linux Kernel Zig Style Conventions

1. **Indentation**: 1 Tab (8 spaces) strictly. Disable or ignore `zig fmt` 4-space default.
2. **Brace Placement**: The opening brace `{` for a function declaration must be on the next line. For control flow (`if`, `switch`), the opening brace is on the same line.
3. **Naming**: `snake_case` for variables, functions, and files. `PascalCase` for types.
4. **Control Flow**: Early returns. Keep the "happy path" flat. Maximum 2 levels of indentation inside function bodies.
5. **Error Handling**: Use Zig's `error` sets. Never use `catch unreachable`. Use `defer` and `errdefer` instead of `goto`.
6. **Comments**: No inline comments explaining logic. Use `///` only for exported/public APIs. 
7. **No Emojis**: Never use emojis anywhere in the codebase.
