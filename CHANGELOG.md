# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] - 2026-09-23

### Added

- Pure `frame.validate_close_payload`, re-exported as `root.validate_close_payload`, for application-layer close validation: an empty payload is accepted, a one-byte payload is rejected, the close code must be 1000-1003, 1007-1014, or 3000-4999, and the reason must be valid UTF-8. A bad code returns `error.ProtocolError` (close code 1002) and an invalid reason returns `error.InvalidUtf8` (close code 1007).
- Close status codes `1012` (`service_restart`), `1013` (`try_again_later`), and `1014` (`bad_gateway`) to `StatusCode`.
- Additive C export `zslay_conn_reset`, which abandons partial receive state, including an active fragmented message, without touching the transport and returns `ZSLAY_ERR_INVALID_ARGUMENT` for a null or misaligned handle.
- C11 ABI smoke test `src/c_api_smoke.c`, compiled and linked against the installed `zslay.h` and static library by `zig build test`.
- Standalone benchmark `src/bench.zig`, moved out of the unit test suite and run with `zig build bench`.

### Fixed

- `Conn.get_tx_header_buffer` no longer returns a slice into a local copy of the queued node, removing a use-after-return.
- `Conn.get_tx_header_buffer` returns an empty slice on an empty TX queue, and `Conn.advance_tx_header` returns `error.InvalidLength` instead of reading a stale node.

### Changed

- Distributed release builds use `-Doptimize=ReleaseSafe` instead of `ReleaseFast`, retaining bounds-checking in release artifacts.
- `flake.nix` pins exact Zig 0.16.0 with no fallback and fails closed during install phases.
- `test.yml` widens the pull-request path filter to flake files, workflows, `include/`, `build.zig`, and `**/*.c`.
- `publish.yml` adds a `verify` job that fails when the `v*` tag, `build.zig.zon` version, and `CHANGELOG.md` section disagree, and feeds the matching changelog section into the GitHub release notes.
- Bump the package version to `0.2.0`.

## [0.1.9] - 2026-09-22

### Changed

- Hoisted `ConnConfig`, `FrameNode`, and `FragmentState` to file scope; `Conn.Config` remains as a compatibility alias.
- Renamed `DecodedHeader.extended_len` to `payload_len` and `header_size` to `header_len`; renamed `FrameNode` progress fields to `header_sent` and `payload_sent`.
- Replaced fragmented-message scalar fields with `rx_fragment` and `tx_fragment` `FragmentState` values.
- Added named aliases `MaskingKeyLen`, `MaxFrameHeaderLen`, `FrameHeaderBuffer`, and `FrameQueue`, removing inline magic numbers from buffer sizing.
- Renamed the private C bridge types to `Callbacks` and `ZslayConn` and named the streaming `ChunkBuffer` alias.
- Refreshed the human and LLM documentation for the readable type model.

## [0.1.7] - 2026-09-22

### Added

- Pure helpers `frame.read_length` and `event.header_bytes_needed` that isolate payload-length resolution and header sizing from state mutation.
- Native tests for masking-key rotation offsets, serialized-size boundaries, queue `push_front`/`pop_back`, and extended-header streaming.

### Changed

- The RX state machine advances through a flat iterative loop instead of recursion; TX queue draining remains iterative.
- `event.Conn.queue_frame` declares its explicit error set (`types.Error || error{QueueFull}`); the benchmark uses `std.sort.asc` instead of a bespoke comparator struct.
- `src/c_api.zig` names the chunk-size constant and flattens the masked and unmasked send paths while preserving callback over-report validation.
- Removed the redundant root-module analysis block and refreshed the human and LLM documentation.

## [0.1.5] - 2026-08-29

### Security

- Validate encoded lengths, RSV bits, masking direction, frame and message limits, and fragmented-frame ordering.
- Fail closed when client masking-key generation is unavailable or fails.
- Pin CI and pre-commit dependencies to immutable commits.

### Added

- Install the typed `include/zslay.h` header with the static library.
- Expose chunk offset, total length, and completion metadata through the C receive API.

### Changed

- Require endpoint role and receive limits when initializing Zig and C connections.
- Bound each C receive call to one transport read and one frame callback.

### Removed

- Remove the public vulnerability-report issue form; use the private process in `SECURITY.md`.

## [0.1.3-alpha] - 2026-08-24

### Changed

- **DoD & FP Architecture Overhaul**: Replaced virtual dispatch (callbacks/vtables) with a statically dispatched, pure I/O-agnostic state machine (`RxAction`/`TxAction`) in the core `event.Conn` parser, dramatically improving cache locality and branch prediction.
- Refactored `c_api.zig` to explicitly loop and execute the underlying non-exhaustive I/O actions instead of injecting hidden callbacks across the FFI boundary.
- Removed over 100 lines of boilerplate bridging code across the Zig/C boundary.

## [0.1.2-alpha] - 2026-08-18

### Changed

- Exclude raw static libraries (`.a` / `.lib`) from GitHub Releases, distributing exclusively via standardized `.tar.gz`, `.tar.bz2`, and `.tar.xz` archives. Windows targets are now packaged into standard `.zip` files instead of tarballs.
- Fix Nix store symlink resolution for CI packaging and enforce proper scope for musl/glibc dev environments.
- Update `CI_CD_PIPELINE.md` and `CONTRIBUTE.md` to accurately document the new hermetic tarball packaging procedures and exclusively outputted artifacts.

## [0.1.1-alpha] - 2026-08-18

### Added

- Package compiled artifacts (`.a` and `.o`) into POSIX-compliant, cross-platform archives (`.tar.bz2`, `.tar.gz`, `.tar.xz`) via Nix-hermetic tools in the `publish.yml` GitHub Actions pipeline.

## [0.1.0-alpha] - 2026-08-10

### Added

- Initialize the zslay project: a zero-allocation, I/O-agnostic WebSocket parser written in Zig 0.16.0 based on the wslay C library. Core architecture implemented in `src/`:
  - `types.zig`: DOD-friendly packed structs, passive data types, and opcodes.
  - `frame.zig`: Stateless, low-level XOR masking, encoding, and decoding functions.
  - `event.zig`: Stateful connection state machine and high-level callback execution.
  - `queue.zig`: Zero-allocation DOD data structures like ring buffers.
  - `c_api.zig`: Drop-in C ABI compatibility layer for external FFI consumers.
  - `root.zig`: Module root exposing public APIs for native Zig usage.
  - `test.zig`: Unified testing module.
- Add `flake.nix` utilizing `flake-parts` for a reproducible, cross-compilation development environment targeting Linux (glibc/musl), macOS, and Windows without requiring a complex CI matrix.
- `nix flake check` integration in `flake.nix` with explicit `checks` and `formatter` outputs to natively support testing across architectures, specifically protecting and utilizing `pkgs.pkgsMusl` environments.
- Add `build.zig` and `build.zig.zon` to support both native Zig module integration and static library (`.a`/`.lib`) generation for C/C++ FFI consumers.
- Add GitHub Actions CI/CD pipelines: `lint.yml` (strict formatting), `test.yml` (Zig unit tests), and `publish.yml` (Nix-driven multi-platform releases).
- `publish.yml` GitHub Action to automatically cross-compile (`nix build`) static libraries for Windows, macOS, and Linux targets when a `v*` tag is pushed, and bundle them in a GitHub Release using `softprops/action-gh-release@v3`.
- Pre-commit hook configuration requiring `zig build test` alongside `zig-fmt` for all contributors to enforce strict local testing.
- Add `CODEBASE.md` and `CODING_CONVENTION.md` to document the Data-Oriented Design (DOD) architecture and Linux Kernel coding style conventions (snake_case, flat control flow, explicit memory).
- Add `CONTRIBUTE.md` and `CI_CD_PIPELINE.md` to establish the development setup, conventional commits, testing requirements, and the tag-driven release flow.
- Add `security_vulnerability.yml` issue template strictly tailored for reporting memory safety issues, out-of-bounds reads, and parser panics.

### Changed

- Hardened `test.yml` GitHub Action for production with concurrency cancellation, `nix flake check` execution, and automated `zig fmt --check` gates. Optimized trigger paths to run on all PRs to `main`, while only triggering on direct pushes to `main` if `.zig` or `.zon` files are modified.
- Upgraded `actions/checkout` and `actions/upload-artifact` to `v7`, and `actions/download-artifact` to `v8` across CI workflows.
