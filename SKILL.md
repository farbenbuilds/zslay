# Global SKILL.md

This document provides a summary of all the available AI agent skills configured for the `zslay` project.

## Core Project Skills

- **zslay-c-ffi**: C ABI / FFI Boundary rules for the zslay project. Used when modifying `src/c_api.zig` or FFI-facing types in `src/types.zig`.
- **zslay-dod**: Data-Oriented Design (DOD) constraints for the zslay project. Used when writing core parser logic, structs, or state machines.
- **zslay-style**: Linux Kernel Zig Style coding conventions for the zslay project. Used when writing, formatting, or refactoring code.
- **wslay-porting**: Guidelines for porting and optimizing original wslay C code into pure Zig using FP, DOD, and Zig best practices.

## Zig & Tooling Skills

- **zig-0.16**: Zig 0.16.0 API guidance and porting notes. Used when writing or upgrading Zig code to the 0.16.0 stable release.
- **zig-best-practices**: Used when reading or writing Zig files (`.zig`, `build.zig`, `build.zig.zon`).
- **zig-testing**: Zig testing skill for writing and running tests (comptime testing, test allocators, fuzz testing).
- **nix-best-practices**: Guidelines for working with Nix flakes, overlays, shell.nix, or flake.nix files.
- **nix-hermetic**: Nix and CI/CD workflow constraints for the zslay project. Used when running commands, testing, or updating CI pipelines.

## General Agent Behaviors & Workflows

- **pragmatic-functional-programming**: A practical, jargon-free guide to functional programming - the 80/20 approach that gets results without the academic overhead.
- **caveman**: Ultra-compressed communication mode to cut output tokens by speaking concisely while keeping technical accuracy.
- **ponytail**: Forces the laziest solution that actually works: simplest, shortest, most minimal. Questions if the task needs to exist (YAGNI) and reaches for standard libraries first.
- **context7**: Retrieve up-to-date documentation for software libraries, frameworks, and components.
- **dod**: Apply Data-Oriented Design (DoD) to optimize memory layout, data locality, and throughput while making ownership-aware performance decisions.
- **github-git**: Rules for Git and GitHub workflows. Enforces checks, correct formatting, and clean history before pushing code.
