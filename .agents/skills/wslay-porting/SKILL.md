---
name: wslay-porting
description: Guidelines for porting and optimizing original wslay C code into pure Zig.
---

# Wslay Porting Guidelines

This skill provides constraints and guidelines for porting logic from the original C-based `wslay` project to the `zslay` pure Zig implementation. 
When rewriting or replicating functions (e.g., websocket frame parsing, masking, state management), you must produce highly optimized, memory-safe, and idiomatic Zig code.

## Core Directives

1. **Understand Original Intent:** Deeply understand the behavior and edge-cases of the original `wslay` C implementation before writing Zig code.
2. **Apply Data-Oriented Design (DOD):** Ensure new structs and logic adhere strictly to DoD principles (`dod` and `zslay-dod` skills). Keep memory contiguous and optimize for L1/L2 cache locality.
3. **Pragmatic Functional Programming (FP):** Favor pure functions without side-effects for parsing steps (`pragmatic-functional-programming` skill). Pass state explicitly rather than relying on hidden mutations.
4. **Follow Zig Best Practices:** Use Zig's compile-time features (`comptime`), explicit error handling, and slices appropriately (`zig-best-practices` skill).
5. **Linux Coding Style:** Adhere to the Linux kernel coding style and `zslay-style` conventions. Keep code minimal, clean, and well-organized. 
6. **Zero-Allocation:** Ensure that ported logic dynamically allocates NO memory at runtime.
