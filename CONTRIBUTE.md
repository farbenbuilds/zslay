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
zig build test            # run unit tests in src/test.zig and the C ABI smoke test
zig build bench           # run the standalone encode/decode benchmark
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

This project uses `pre-commit` to guarantee code formatting, syntax correctness, and type safety before any commit is created. The `pre-commit` tool is not bundled in the Nix development shell; install it with your system package manager or `pipx` before running the hooks.

After cloning the repository, install the git hooks locally:

```bash
pre-commit install

```

Every time you run `git commit`, the following checks will execute automatically (fail-fast):

1. **zig-fmt**: Auto-formats staged `.zig` files.
2. **zig-build-test**: Runs `zig build test`, which includes the C ABI smoke test.

Generic hygiene hooks (`trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-added-large-files`, `check-merge-conflict`) also run.

To run all checks manually across the entire codebase at any time:

```bash
pre-commit run --all-files

```

## AI Agent Workflows

Specialized sub-agents are defined in `.opencode/agents/` and follow the same rules as human contributors: one scope per change, `zig fmt --check .`, and `zig build test` before review.

- Use `zslay-parser`, `zslay-event-loop`, `zslay-c-abi`, `zslay-node-api`, `zslay-testing`, `zslay-release`, and `zslay-docs` for isolated work in their owned paths.
- Use `zslay-review` (read-only) before opening or merging a pull request.
- Agents hand cross-scope changes to the owning agent instead of editing outside their scope.
- Do not let an agent commit, push, tag, or open a pull request unless you explicitly asked for it.

The roster, owned paths, delegation rules, and skill coverage matrix live in [AGENT_DIRECTORY.md](AGENT_DIRECTORY.md).

## Commit Convention

Angular-style conventional commits. Format: `<type>(<scope>): <subject>`

Types: `feat`, `fix`, `perf` (appear in changelog), `build`, `ci`, `docs`, `style`, `refactor`, `test`.
Subject: imperative present tense, no capital first letter, no trailing period.
Example: `feat(core): implement dod frame header packed struct`

## CI/CD

Full pipeline reference: [CI_CD_PIPELINE.md](CI_CD_PIPELINE.md).

- Lint (`lint.yml`): runs `zig fmt --check .` on every pull request into `main` modifying `.zig`, `.zon`, or `build.zig` files (Ubuntu, Zig 0.16.0 via `mlugg/setup-zig`).
- Test (`test.yml`): on every pull request and push to `main`, runs `zig fmt --check .` and `nix flake check` inside Nix. The flake checks build the native and musl test derivations, and `zig build test` includes the C ABI smoke test.
- Release (`publish.yml`): triggered by pushing a version tag matching `v*` (e.g. `v0.2.0`). The `verify` job fails when the tag, the `build.zig.zon` version, and the matching `CHANGELOG.md` section disagree, and passes that section to the release job as the release notes.
  Uses Nix `flake-parts` to cross-compile the static library (`.a` / `.lib`) with `ReleaseSafe` across multiple targets (Linux glibc/musl, macOS, Windows), exclusively packages Linux/macOS targets into tarballs (`.tar.bz2`, `.tar.gz`, `.tar.xz`) and Windows targets into `.zip` natively using the `flake.nix` dev shell, creates the GitHub release named after the tag with the extracted notes, and uploads the generated archives to the release.

## Cutting a Release

Releases follow semantic versioning and are driven by `v*` tags, not by pushes to `main`.

1. Bump the version in `build.zig.zon`.
2. Add a `## [x.y.z]` section to `CHANGELOG.md`; the `verify` job requires the tag, the
   `build.zig.zon` version, and this section to agree, and extracts the section as the
   release notes (tag `v0.2.0` maps to section `## [0.2.0]`).
3. Land the bump on `main` through a pull request.
4. Tag the release commit and push the tag:

```bash
git tag v0.2.0
git push origin v0.2.0

```

The tag push triggers `publish.yml` to compile and distribute the static library artifacts. Keep the version in `build.zig.zon` in sync with the tag so downstream projects like `uWebZockets` can depend on the exact commit hash and version.
