# zslay - CI/CD Pipeline

Reference for the GitHub Actions pipelines: what runs, when, and what they produce. This project leverages **Nix** (`flake.nix`) and Zig's native cross-compilation, allowing us to build for multiple architectures from a single CI runner with perfect reproducibility.

For the step-by-step release procedure, see [CONTRIBUTE.md](CONTRIBUTE.md); for architecture and data structures, see [CODEBASE.md](CODEBASE.md).

## Workflows

| Workflow                          | Trigger                             | Purpose                                         |
| --------------------------------- | ----------------------------------- | ----------------------------------------------- |
| `.github/workflows/lint.yml`      | Pull request into `main`            | Code formatting check (`zig fmt --check .`)     |
| `.github/workflows/test.yml`      | Pull request into `main`            | Native Zig unit tests                           |
| `.github/workflows/publish.yml`   | Push of a version tag matching `v*` | Cross-platform build via Nix and GitHub release |

## Lint Pipeline (`lint.yml`)

Runs on every pull request into `main` that modifies source files:

1. Checkout repository.
2. Setup Nix and Zig 0.16.0 environment.
3. Executes `zig fmt --check .` (strict formatting check; fails the PR if files are dirty).

## Test Pipelines

Ensures the parser's memory safety, correctness, and RFC 6455 compliance.

### 1. Zig Unit Tests (`test.yml`)

Tests the core parser logic, Data-Oriented Design (DOD) memory layouts, and state machine transitions directly at the systems level.

- Environment: Nix shell (Zig 0.16.0).
- Command: `zig build test`
- Scope: Executes all `test` blocks defined in `src/test.zig` and other Zig source files.

## Release Pipeline (`publish.yml`)

Triggered by pushing a semver tag such as `v0.1.0`. Releases are driven by tags, not by pushes to `main`.

Because we use `flake.nix`, a **single `ubuntu-latest` runner** compiles artifacts for all platforms natively, removing the need for expensive and slow macOS or Windows CI runners.

### Job: `publish-artifacts`

1. Checkout repository.
2. Setup Nix (with `flake-parts`) and Zig 0.16.0.
3. Derives the version from the tag (`v0.1.0` becomes `0.1.0`).
4. Extracts the release notes from the matching `## [0.1.0]` section of `CHANGELOG.md`.
5. Calls `nix build` sequentially for the targets defined in `flake.nix`:
   - `linux-x86_64-gnu` -> builds `libzslay-x86_64-linux-gnu.a`
   - `linux-x86_64-musl` -> builds `libzslay-x86_64-linux-musl.a`
   - `linux-aarch64-gnu` -> builds `libzslay-aarch64-linux-gnu.a`
   - `linux-aarch64-musl` -> builds `libzslay-aarch64-linux-musl.a`
   - `macos-x86_64` -> builds `libzslay-x86_64-macos.a`
   - `macos-aarch64` -> builds `libzslay-aarch64-macos.a`
   - `windows-x86_64` -> builds `zslay-x86_64-windows.lib`
6. Packages Linux and macOS artifacts exclusively into cross-platform archives (`.tar.bz2`, `.tar.gz`, `.tar.xz`) utilizing hermetic tools (`gnutar`, `bzip2`, `gzip`, `xz`). Windows targets are packaged into `.zip` archives utilizing the `zip` tool. All tools are provided via `flake.nix` dev shells. The raw `.a`/`.lib` files are strictly omitted from the payload.
7. Creates (or updates) the GitHub Release named after the tag and uploads the generated tarball archives.

## Required Secrets

| Secret         | Used for                                             |
| -------------- | ---------------------------------------------------- |
| `GITHUB_TOKEN` | Creating the release and uploading assets (built in) |

## Versioning Rules

- Semantic versioning; the `v*` tag is the single release trigger.
- The tag must match the version declared in `build.zig.zon`, and a matching `CHANGELOG.md` section must exist. The full checklist lives in [CONTRIBUTE.md](CONTRIBUTE.md).
