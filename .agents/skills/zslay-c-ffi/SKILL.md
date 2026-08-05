---
name: zslay-c-ffi
description: >
  C ABI / FFI Boundary rules for the zslay project.
  Use when modifying `src/c_api.zig` or FFI-facing types in `src/types.zig`.
---

# zslay - C ABI / FFI Boundary Constraints

1. **Explicit integer sizes**: Explicitly define backing integer sizes for enums and structs (e.g., `enum(c_int)` or `packed struct(u16)`).
2. **Boundary types**: Use `extern struct` for types that cross the C FFI boundary.
3. **Naming exports**: Prefix all C-exported functions with `zslay_`.
4. **No slices across boundary**: Never pass Zig slices (`[]u8`) directly across FFI boundaries. Always decompose them into a many-item pointer (`[*]u8`) and a length (`usize`).
5. **Opaque context**: Expose stateful contexts as opaque structures (`*anyopaque`).
