---
name: zslay-style
description: >
  Linux Kernel Zig Style coding conventions for the zslay project.
  Use when writing, formatting, or refactoring code.
---

# zslay - Linux Kernel Zig Style Conventions

1. **Formatting**: Always use standard `zig fmt` for indentation, spaces, and brace placements. Run `zig fmt .` before any commits.
2. **Naming**: Follow Linux style conventions for naming: `snake_case` for variables, functions, and files. `PascalCase` for types.
4. **Control Flow**: Early returns. Keep the "happy path" flat. Maximum 2 levels of indentation inside function bodies.
5. **Error Handling**: Use Zig's `error` sets. Never use `catch unreachable`. Use `defer` and `errdefer` instead of `goto`.
6. **Comments**: No inline comments explaining logic. Always use `//` for all comments. Do NOT use `///` or block comments (`/* */`). 
7. **No Emojis**: Never use emojis anywhere in the codebase.
