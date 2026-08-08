---
name: nix-hermetic
description: >
  Nix and CI/CD workflow constraints for the zslay project.
  Use when running commands, testing, or updating CI pipelines.
---

# zslay - Nix & CI/CD Workflow Constraints

1. **Hermetic Environment**: Do not suggest or write scripts that install global dependencies via `apt`, `brew`, or `npm`.
2. **Flake & Direnv**: All development dependencies are managed via `flake.nix` and loaded via `direnv`. This guarantees Zig 0.16.0 availability natively.
3. **Native Testing**: Run tests via `zig build test` in the Nix shell.

5. **Artifact Building**: Cross-compilation of static libraries (`.a`/`.lib`) across platforms is done exclusively via `nix build`.
