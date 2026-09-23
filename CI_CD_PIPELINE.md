# zslay - CI/CD Pipeline

Reference for the GitHub Actions pipelines: what runs, when, and what they produce. This project leverages **Nix** (`flake.nix`) and Zig's native cross-compilation, allowing us to build for multiple architectures from a single CI runner with perfect reproducibility.

For the step-by-step release procedure, see [CONTRIBUTE.md](CONTRIBUTE.md); for architecture and data structures, see [CODEBASE.md](CODEBASE.md).

## Workflows

| Workflow                          | Trigger                                          | Purpose                                                                 |
| --------------------------------- | ------------------------------------------------ | ----------------------------------------------------------------------- |
| `.github/workflows/lint.yml`      | Pull request into `main` (Zig and build paths)   | Formatting check (`zig fmt --check .`) with Zig 0.16.0                  |
| `.github/workflows/test.yml`      | Pull request into `main`, push to `main`         | Formatting gate, `nix flake check`, native and musl tests               |
| `.github/workflows/publish.yml`   | Push of a version tag matching `v*`              | Release verification, cross-platform build via Nix, GitHub release      |

## Lint Pipeline (`lint.yml`)

Runs on every pull request into `main` that modifies `.zig`, `.zon`, or `build.zig` files:

1. Checkout repository.
2. Setup Zig 0.16.0 with `mlugg/setup-zig` (no Nix).
3. Executes `zig fmt --check .` (strict formatting check; fails the PR if files are dirty).

## Test Pipeline (`test.yml`)

Ensures the parser's memory safety, correctness, and RFC 6455 compliance.

Tests the core parser logic, Data-Oriented Design (DOD) memory layouts, and state machine transitions directly at the systems level.

- Environment: Nix (`cachix/install-nix-action`) with evaluation caching keyed on `flake.lock`.
- Commands:
  - `nix develop -c zig fmt --check .`
  - `nix flake check --print-build-logs`
- Scope: `flake check` builds the native and musl `test` derivations, which run `zig build test`. That step executes all `test` blocks defined in `src/test.zig` and other Zig source files, and also compiles, links, and runs the C11 ABI smoke test `src/c_api_smoke.c`.
- Pull-request path filter: Zig sources, flake files, workflows, `include/`, `build.zig`, and `**/*.c`.

## Release Pipeline (`publish.yml`)

Triggered by pushing a semver tag such as `v0.2.0`. Releases are driven by tags, not by pushes to `main`.

Because we use `flake.nix`, the `build` job runs on `ubuntu-latest` and compiles artifacts for all platforms natively, removing the need for expensive and slow macOS or Windows CI runners.

### Job: `verify`

Runs first; `build` and `release` depend on it.

1. Derives the version from the tag (`v0.2.0` becomes `0.2.0`).
2. Fails the workflow when the tag, the `build.zig.zon` version, and the matching `CHANGELOG.md` section disagree.
3. Extracts the release notes from the matching `## [0.2.0]` section of `CHANGELOG.md` and uploads them as the `release-notes` artifact.

### Job: `build`

Runs after `verify` succeeds.

1. Checkout repository and setup Nix with evaluation caching.
2. Calls `nix build .#<target>` across a target matrix defined in `flake.nix`, all built with `-Doptimize=ReleaseSafe`:
   - `default`
   - `linux-x86_64-gnu` -> builds `libzslay-x86_64-linux-gnu.a`
   - `linux-x86_64-musl` -> builds `libzslay-x86_64-linux-musl.a`
   - `linux-aarch64-gnu` -> builds `libzslay-aarch64-linux-gnu.a`
   - `linux-aarch64-musl` -> builds `libzslay-aarch64-linux-musl.a`
   - `macos-x86_64` -> builds `libzslay-x86_64-macos.a`
   - `macos-aarch64` -> builds `libzslay-aarch64-macos.a`
   - `windows-x86_64` -> builds `zslay-x86_64-windows.lib`
3. Packages Linux and macOS artifacts exclusively into cross-platform archives (`.tar.bz2`, `.tar.gz`, `.tar.xz`) utilizing hermetic tools (`gnutar`, `bzip2`, `gzip`, `xz`). Windows targets are packaged into `.zip` archives utilizing the `zip` tool. All tools are provided via `flake.nix` dev shells. The raw `.a`/`.lib` files are strictly omitted from the payload.
4. Uploads the archives as workflow artifacts for the `release` job.

### Job: `release`

Runs after `build` succeeds.

1. Downloads and merges the `zslay-*` build artifacts and the `release-notes` artifact.
2. Creates (or updates) the GitHub Release named after the tag with the changelog-derived release notes and uploads the generated archives.

## Required Secrets

| Secret         | Used for                                             |
| -------------- | ---------------------------------------------------- |
| `GITHUB_TOKEN` | Creating the release and uploading assets (built in) |

## Versioning Rules

- Semantic versioning; the `v*` tag is the single release trigger.
- The tag must match the version declared in `build.zig.zon`, and a matching `CHANGELOG.md` section must exist. The `verify` job fails the release when the three disagree, and the matching changelog section becomes the release notes. The full checklist lives in [CONTRIBUTE.md](CONTRIBUTE.md).
