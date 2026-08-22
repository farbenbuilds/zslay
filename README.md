<div align="center">
  <img src="misc/zslay-banner.png" alt="zslay banner" />
</div>

# zslay - Zero-allocation, I/O-agnostic WebSocket framing library

`zslay` is a pure Zig (0.16.0) port of the C-based `wslay` library. It acts as a highly optimized, memory-safe, and I/O-agnostic core for parsing WebSocket (RFC 6455) frames. 

## Why Zig 0.16.0?

Zig 0.16.0 brings a suite of powerful features perfectly suited for systems-level parsers:
- **Zero Hidden Control Flow:** Predictable performance with no hidden allocations or exceptions.
- **Memory Safety:** Built-in spatial safety and compile-time checks catch bounds and alignment errors early.
- **Fast Compilation & FFI:** Drop-in C ABI compatibility natively without overhead. It smoothly integrates with Node.js, Python, Rust, and others via C FFI.
- **Modern standard library:** Embraces the modern `std.io` architecture while avoiding deprecated builtins, ensuring long-term stability.

## Data-Oriented Design (DOD)

This project strictly adheres to Data-Oriented Design principles to squeeze out maximum performance:
- **Zero-Allocation:** No dynamic memory allocation during standard parser execution. `zslay` utilizes bounded ring buffers and pre-allocated static contexts instead of heap allocators.
- **Cache-Efficient:** Eliminates pointer chasing. We use explicit, small integers (`u16`, `u32`) as indices for state tracking to maximize CPU L1/L2 cache locality.
- **Flat Layouts:** Heavy usage of `packed struct` mapped directly to hardware/protocol byte boundaries (e.g., `FrameHeader`).

## An Improved RFC6455 Implementation

`zslay` is not just a port; it's an enhancement over traditional implementations:
- **Purely I/O-Agnostic:** It treats parsing as a pure data transformation engine. `zslay` does not touch network sockets. You feed it slices of raw bytes, and it yields structured events.
- **Memory Predictability:** By keeping state management outside the library and avoiding heap allocations entirely, `zslay` is completely deterministic in its memory usage.
- **Secure by Default:** Zig's strict bounds checking guarantees resilience against malformed or malicious WebSocket payloads.

## Getting Started

Development is strictly pinned using Nix to guarantee bit-for-bit reproducibility across all OS platforms. No global dependencies (like apt, brew, or npm) are required.

### Prerequisites
- Install Nix.
- Enable Nix Flakes.
- (Optional but recommended) Install direnv.

### Clone, Dev, and Build

**1. Clone the repository**
```bash
git clone https://github.com/farbenbuilds/zslay.git
cd zslay
```

**2. Enter the hermetic Nix environment**  
*(Provides Zig 0.16.0 and all necessary tooling)*
```bash
nix develop
```
*Or, if you use direnv:*
```bash
direnv allow
```

**3. Install pre-commit hooks (Optional but recommended)**
```bash
pre-commit install
```

**4. Run native tests**
```bash
zig build test
```

**5. Format the code**
```bash
zig fmt .
```

## Credits

`zslay` is heavily inspired by and ported from the original C WebSocket library, [wslay](https://github.com/tatsuhiro-t/wslay), created by Tatsuhiro Tsujikawa. We extend our gratitude for their foundational work.

## uWebZockets

`zslay` is designed to be the foundational core of **[uWebZockets](https://github.com/farbenbuilds/uWebZockets)**, an implementation of the highly acclaimed `uWebSockets` library, fully written in pure Zig. 
uWebZockets brings industry-leading concurrency and throughput to the Zig ecosystem, leveraging `zslay`'s zero-allocation protocol parsing at its heart.
