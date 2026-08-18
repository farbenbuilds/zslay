# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
