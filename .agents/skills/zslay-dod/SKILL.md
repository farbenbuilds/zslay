---
name: zslay-dod
description: >
  Data-Oriented Design (DOD) constraints for the zslay project. 
  Use when writing core parser logic, structs, or state machines.
---

# zslay - Data-Oriented Design (DOD) Constraints

1. **Flatten data structures**: Use `packed struct` for exact hardware/network layouts to guarantee zero padding.
2. **No pointer chasing**: Do not nest stateful contexts with arbitrary heap pointers.
3. **Index over pointer**: Track state using small explicit integers (e.g., `u16` index).
4. **Zero-Allocation**: No `std.heap` allocators. Use bounded ring buffers or pre-allocated static contexts provided by the library consumer.
5. **Static Dispatch**: Optimize branch prediction by using `switch` on non-exhaustive enums instead of virtual dispatch (`vtable`).
