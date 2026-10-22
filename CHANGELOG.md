# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.3.0] - 2026-10-22

### Added

- `zslay_conn_tx_pending` reports whether borrowed transmit payloads are still live; `zslay_conn_reset_tx` clears queued frames and open fragments; `zslay_conn_deinit` retires caller-owned handles.
- `zslay_abi_version` and an opaque-handle magic/version check reject stale, uninitialized, and wrong-object C handles.
- `zslay_validate_close_payload` exposes close-code and UTF-8 reason validation to C consumers.
- `Conn.get_tx_payload`, `Conn.get_tx_payload_offset`, `Conn.get_tx_masking_key`, and `Conn.advance_tx_payload` provide a checked transmit-payload API instead of direct queue access.
- `Conn.is_at_frame_boundary`, `Conn.tx_pending`, `Conn.reset_tx`, `frame.header_bytes_needed`, and `frame.is_valid_close_code`.
- C receive staging uses a 14-byte per-connection stage to coalesce the header and payload prefix, reducing transport reads without adding another large per-connection buffer.
- Ping and pong frames preempt an unsent queue head, so control latency does not wait behind queued data frames.
- `test-release-safe` coverage is part of `zig build test`; the release safety model is exercised on every run.
- `.gitattributes` marks vendored agent tooling as non-source so GitHub reports Zig as the primary language.

### Fixed

- `encode_header` now derives the wire marker from `payload_len` and rejects marker/payload mismatches. This closes the short-marker truncation and control-frame limit bypass.
- `encode_header` rejects a masking key supplied for an unmasked header instead of silently dropping it.
- Masking uses a word width that is always a multiple of four bytes, fixing corruption on 16-bit targets and removing a theoretical loop-bound overflow.
- `validate_close_payload` rejects payloads over 125 bytes, and `decode_header` rejects one-byte close payloads.
- `Conn.complete_frame` returns `error.ProtocolError` for a partially consumed payload; callers must use `reset_rx` to abandon a frame deliberately.
- Zero-byte header, payload, and transmit advances return `error.InvalidLength` instead of allowing a livelock.
- Outbound close frames are validated by `Conn.prepare_frame` before serialization.
- Outgoing nodes with a null payload pointer and a nonzero length are rejected.
- The C adapter detects callback reentrancy and returns `ZSLAY_ERR_REENTRANT`; `on_frame` may still enqueue a response.
- `zslay_conn_init` rejects client connections without a mask generator, overlapping connection/transmit storage, oversized transmit counts, and invalid alignment.
- C `send` caps callbacks, total bytes, masked chunks, and unmasked chunks per call, so a fast peer or one-byte writes cannot monopolize the event loop.
- C `prepare_frame` and `queue_frame` reject node storage that overlaps the connection, an active queued slot, or the receive chunk, and reject payload storage that overlaps zslay-owned memory or the node.
- `on_frame` receive chunks are rejected as queued payloads, preventing a transient stack pointer from becoming a borrowed transmit payload.
- `zslay_conn_init` uses a thread-local callback-depth guard instead of reading possibly uninitialized handle memory and rejects reinitialization from any callback.

### Changed

- Require Zig `0.17.0`; migrate to `@backingInt`/`@fromBackingInt`, `@splat`, and the current test/build APIs.
- Bump the package version to `0.3.0`.
- `get_serialized_size` returns `error.InvalidLength` for payloads above `MaxPayloadLen` instead of a plausible but unencodable size.
- The C connection context now includes a 4 KiB masked transmit scratch chunk; allocate it from `zslay_conn_get_size` and recompile fixed-size consumers.
- `zslay_conn_send` returns `ZSLAY_PROGRESS` when its callback budget expires and `ZSLAY_OK` when the queue drains or the transport would block.
- C `prepare_frame` and `queue_frame` now return `ZSLAY_ERR_INVALID_ARGUMENT` for local frame-direction, opcode, and limit errors, `ZSLAY_ERR_INVALID_UTF8` for a bad close reason, and `ZSLAY_ERR_PROTOCOL` for invalid protocol state; the mapping is documented in `include/zslay.h`.
- Queue wrap uses branch-based index updates, and `Queue.clear`/`Queue.front` replace direct field access in hot paths.
- The echo benchmark reads handshakes in chunks, keeps bytes that arrive after the HTTP headers, uses a poll timeout with a 30-second idle limit, caps accepts per iteration, and uses separate node and transmit storage.

### Performance

- Cached masked transmit chunks avoid re-copying and re-masking up to 4 KiB after every partial send or would-block.
- Header encode and decode benchmarks improved from about 1.25 ns/op to 0.63 ns/op and 1.63 ns/op to 0.83 ns/op respectively on the reference runner.
- Masking remains word-at-a-time within a fixed 4 KiB callback chunk.

### Security

- Validate close frame length, status code, and UTF-8 reason on the outbound path and expose the validator to C.
- Reject stale or forged C handles, overlapping storage, and reentrant state-machine calls.
- Bound C send work per invocation and cap unmasked transport chunks.
- Bound echo-server handshake reads, accepts, and idle connection lifetime.

## [0.2.1] - 2026-09-24

### Fixed

- `direnv allow` on musl hosts no longer triggers source builds of LLVM, Clang, LLD, Zig, and zls. `devShells.musl` now reuses the cached zig-overlay Zig, `zls`, and archive tools instead of requesting the uncached `pkgsMusl` variants.

### Changed

- `zig-overlay` follows the root `nixpkgs` input, removing the duplicate nixpkgs fetch and evaluation.
- Bump the package version to `0.2.1`.

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
