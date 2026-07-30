# zslay - Contributing Guide

How to set up, develop, test, commit, and release. For architecture see [CODEBASE.md](CODEBASE.md); for code style see [CODING_CONVENTION.md](CODING_CONVENTION.md).

## Build / Dev / Lint Commands

Development environment is managed via Nix flakes. Code is written in Zig 0.16.0.

```bash
nix develop               # enter the reproducible dev shell with Zig 0.16.0
nix build                 # build cross-platform artifacts via flake-parts

```

Zig backend (run from project root):

```bash
zig build                 # build the static library artifact (outputs to zig-out/lib/)
zig build test            # run unit tests in src/test.zig
zig fmt --check .         # lint code (strict, fails if formatting is dirty)
zig fmt .                 # format code automatically

```

## Testing

Tests are managed by the built-in Zig testing framework. We isolate tests in `src/test.zig` to keep the public API (`src/root.zig`) clean.

Before submitting a pull request, ensure all tests pass:

```bash
zig build test

```

## Pre-commit Hooks

No automated pre-commit hook is currently configured locally.
Always run `zig fmt .` and `zig build test` before committing to ensure the CI pipeline does not fail on your pull request.

## Commit Convention

Angular-style conventional commits. Format: `<type>(<scope>): <subject>`

Types: `feat`, `fix`, `perf` (appear in changelog), `build`, `ci`, `docs`, `style`, `refactor`, `test`.
Subject: imperative present tense, no capital first letter, no trailing period.
Example: `feat(core): implement dod frame header packed struct`

## CI/CD

Full pipeline reference: [CI_CD_PIPELINE.md](CI_CD_PIPELINE.md).

- Lint (`lint.yml`): runs `zig fmt --check .` on every pull request into `main` modifying `.zig`, `.zon`, or `build.zig` files (Ubuntu, Zig 0.16.0).
- Release (`publish.yml`): triggered by pushing a version tag matching `v*` (e.g. `v0.1.0`).
  Uses Nix `flake-parts` to cross-compile the static library (`.a` / `.lib`) across multiple targets (Linux glibc/musl, macOS, Windows), creates the GitHub release named after the tag with notes extracted from the matching `CHANGELOG.md` section, and uploads the compiled artifacts to the release.

## Cutting a Release

Releases follow semantic versioning and are driven by `v*` tags, not by pushes to `main`.

1. Bump the version in `build.zig.zon`.
2. Add a `## [x.y.z]` section to `CHANGELOG.md`; the workflow extracts the release notes
   from it (tag `v0.1.0` maps to section `## [0.1.0]`).
3. Land the bump on `main` through a pull request.
4. Tag the release commit and push the tag:

```bash
git tag v0.1.0
git push origin v0.1.0

```

The tag push triggers `publish.yml` to compile and distribute the static library artifacts. Keep the version in `build.zig.zon` in sync with the tag so downstream projects like `uWebZockets` can depend on the exact commit hash and version.
