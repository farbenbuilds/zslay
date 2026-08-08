# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0-dev] - 2026-07-31

### Added

- Initialize the zslay project: a zero-allocation, I/O-agnostic WebSocket parser written in Zig 0.16.0 based on the wslay C library.
- Add `flake.nix` utilizing `flake-parts` for a reproducible, cross-compilation development environment targeting Linux (glibc/musl), macOS, and Windows without requiring a complex CI matrix.
- Add `build.zig` and `build.zig.zon` to support both native Zig module integration and static library (`.a`/`.lib`) generation for C/C++ FFI consumers.
- Add GitHub Actions CI/CD pipelines: `lint.yml` (strict formatting), `test.yml` (Zig unit tests), and `publish.yml` (Nix-driven multi-platform releases).
- Add `CODEBASE.md` and `CODING_CONVENTION.md` to document the Data-Oriented Design (DOD) architecture and Linux Kernel coding style conventions (snake_case, flat control flow, explicit memory).
- Add `CONTRIBUTE.md` and `CI_CD_PIPELINE.md` to establish the development setup, conventional commits, testing requirements, and the tag-driven release flow.
- Add `security_vulnerability.yml` issue template strictly tailored for reporting memory safety issues, out-of-bounds reads, and parser panics.
