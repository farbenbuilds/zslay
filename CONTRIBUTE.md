# zslay - Contributing Guide

How to set up, develop, test, commit, and release. For architecture see [CODEBASE.md](CODEBASE.md); for code style see [CODING_CONVENTION.md](CODING_CONVENTION.md).

## Local Setup & Initialization

This project strictly relies on Nix for a reproducible development environment. You do not need to install Zig manually on your host OS.

### Prerequisites

- Install [Nix](https://nixos.org/download) with Flakes enabled.
- Install [direnv](https://direnv.net/) and hook it into your shell.

### Initialization

1. Clone the repository:

```bash
git clone https://github.com/farbenbuilds/zslay.git

cd zslay

```

2. Allow direnv to read the `.envrc` file and load the workspace. This will automatically fetch Zig 0.16.0 and required build tools natively via `flake.nix`:

```bash
direnv allow

```

3. Verify the environment is properly isolated:

```bash
zig version # Must output 0.16.0

```

## Build / Dev / Lint Commands

Development environment is managed via Nix flakes. Code is written in Zig 0.16.0.

```bash
nix develop               # enter the reproducible dev shell manually (if not using direnv)
nix build                 # build cross-platform artifacts via flake-parts

```

Zig backend (run from project root):

```bash
zig build                 # build the static library artifact (outputs to zig-out/lib/)
zig build test            # run unit tests in src/test.zig
zig build check           # run semantic linter (type-check without emitting binaries)
zig fmt --check .         # verify code formatting
zig fmt .                 # format code automatically

```

## Testing

Tests are managed by the built-in Zig testing framework. We isolate tests in `src/test.zig` to keep the public API (`src/root.zig`) clean.

Before submitting a pull request, ensure all tests pass:

```bash
zig build test

```

## Pre-commit Hooks

This project uses `pre-commit` to guarantee code formatting, syntax correctness, and type safety before any commit is created. The `pre-commit` tool is automatically provided by our Nix development shell.

After cloning the repository, install the git hooks locally:

```bash
pre-commit install

```

Every time you run `git commit`, the following checks will execute automatically (fail-fast):

1. **zig-fmt**: Auto-formats staged `.zig` files.
2. **zig-ast-check**: Performs a lightning-fast syntax validation.
3. **zig-build-check**: Runs the Zig compiler's semantic analysis and type-checking via `zig build check`.

To run all checks manually across the entire codebase at any time:

```bash
pre-commit run --all-files

```

## Commit Convention

Angular-style conventional commits. Format: `<type>(<scope>): <subject>`

Types: `feat`, `fix`, `perf` (appear in changelog), `build`, `ci`, `docs`, `style`, `refactor`, `test`.
Subject: imperative present tense, no capital first letter, no trailing period.
Example: `feat(core): implement dod frame header packed struct`

## CI/CD

Full pipeline reference: [CI_CD_PIPELINE.md](CI_CD_PIPELINE.md).

- Lint (`lint.yml`): runs `zig fmt --check .` on every pull request into `main` modifying `.zig`, `.zon`, or `build.zig` files (Ubuntu, Zig 0.16.0).
- Test (`test.yml`): runs `zig build test` natively inside a Nix environment on every pull request and push to main.
- Release (`publish.yml`): triggered by pushing a version tag matching `v*` (e.g. `v0.1.0`).
  Uses Nix `flake-parts` to cross-compile the static library (`.a` / `.lib`) across multiple targets (Linux glibc/musl, macOS, Windows), exclusively packages Linux/macOS targets into tarballs (`.tar.bz2`, `.tar.gz`, `.tar.xz`) and Windows targets into `.zip` natively using the `flake.nix` dev shell, creates the GitHub release named after the tag with notes extracted from the matching `CHANGELOG.md` section, and uploads the generated archives to the release.

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
