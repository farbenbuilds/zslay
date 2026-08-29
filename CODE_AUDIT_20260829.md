# Code Audit — 2026-08-29

## Audit Status

| Field | Result |
| --- | --- |
| Revision | `d0c08a1aef06f58110a6f791966972b69cc9579f` |
| Scope | All 55 tracked files, including the PNG asset |
| Security result | 9 validated findings: 1 high, 5 medium, 3 low |
| Allocation result | No heap allocation in production parser paths |
| Leak result | No source-backed leak found; dynamic leak testing was unavailable |
| Secret scan | No credentials, private keys, or tokens found |

This was a static, repository-wide review of the Zig framing core, C ABI, tests,
Nix/build configuration, GitHub workflows, documentation, agent guidance, and
binary asset. The library is in-process and I/O-agnostic; remote impact depends
on how an embedding application exposes it. The C adapter and protocol parser
still own the validation and memory invariants identified below.

## Executive Summary

Fix the frame encoder first. `encode_header` can approve a buffer that is too
short and then write an extended length beyond it. The normal `prepare_frame`
path generates canonical inputs, but the unsafe combination is accepted by the
public Zig API and release artifacts use `ReleaseFast`.

The next priority is the C ABI. It reports payload chunks as frames, silently
uses a zero mask key, lacks endpoint-role mask validation and work limits, and
trusts callback byte counts beyond the buffers offered to them. The zero-
allocation design itself is sound: production code has no allocator, and both
test allocations are freed. The main ownership risk is undocumented borrowed
memory, not an internal leak.

## Validated Security Findings

| ID | Severity | Finding and evidence | Required action |
| --- | --- | --- | --- |
| S-01 | High | **Header encoder out-of-bounds write.** Capacity is calculated from `extended_len`, but the write width is selected from `header.payload_len` (`src/frame.zig:59-77`). Marker 127 plus length 125 accepts two bytes and then writes eight bytes at offset 2. | Validate canonical marker/value pairs before sizing, derive both size and write width from one representation, and add exact-size boundary tests. |
| S-02 | Medium | **C frame-boundary confusion.** `on_frame_fn` runs for each transport chunk with the WebSocket FIN bit; it has no offset/end flag, and nonempty completion has no callback (`src/c_api.zig:14-15`, `83-124`). A 5000-byte frame is indistinguishable from two frames. | Emit one whole-frame event using caller storage, or define a chunk API with start/end, offset, and total length. |
| S-03 | Medium | **Predictable client masking.** Missing or failed key generation becomes `{0,0,0,0}` and preparation succeeds (`src/event.zig:149-178`, `src/c_api.zig:194-211`). | Fail closed when a masked frame has no successful CSPRNG-backed key. |
| S-04 | Medium | **Peer mask direction is not enforced.** `Conn` has no client/server role, both mask states are accepted, and the C event drops the original mask bit (`src/types.zig:37-46`, `src/frame.zig:91-148`, `src/c_api.zig:93-106`). | Require endpoint role and use `PayloadMasked`/`PayloadNotMasked`; retain a separately named raw decoder if needed. |
| S-05 | Medium | **Unbounded receive work.** Lengths through `2^63-1` can drive one `zslay_conn_recv` call through unlimited 4096-byte iterations (`src/frame.zig:118-126`, `src/c_api.zig:69-127`). | Add configurable frame/message ceilings and a per-call byte or chunk budget. |
| S-06 | Medium | **Mutable CI dependencies.** Every action uses a movable version tag, including `softprops/action-gh-release@v3` in a `contents: write` job (`.github/workflows/publish.yml:24-38`, `65-88`). | Pin actions and pre-commit repositories to reviewed full commit SHAs; declare explicit least-privilege permissions. |
| S-07 | Low | **RSV policy is absent.** RSV bits are accepted without negotiated-extension state and erased by the C callback (`src/types.zig:48-58`, `src/frame.zig:91-106`). | Reject RSV bits by default; allow only a negotiated mask in raw/extension-aware APIs. |
| S-08 | Low | **Fragment sequences are not validated.** `complete_frame` retains no active fragmented-message state, allowing orphan continuations or overlapping data frames (`src/event.zig:21-40`, `106-112`). | Track the active data opcode and validate continuation ordering while allowing interleaved control frames. |
| S-09 | Low | **Disclosure instructions conflict.** `SECURITY.md:3-22` forbids public security issues, while the public form invites low/medium or uncertain reports and asks for reproduction details (`.github/ISSUE_TEMPLATE/security_vulnerability.yml:8-55`). | Remove the public form or route it to GitHub private vulnerability reporting. |

The canonical security scan completed under scan ID
`8d3abe67-51fd-4ec1-a5e6-eda4653fd642`. Findings were severity-calibrated with
deployment preconditions; no embedding application or external GitHub policy
was available for inspection.

## Memory Safety, FFI, and Correctness Defects

These are actionable defects even where a malicious same-process caller would
already possess equivalent pointer authority.

| ID | Priority | Defect | Fix |
| --- | --- | --- | --- |
| E-01 | High | Positive receive/send callback results are never checked against the offered length. They become slice bounds and progress counters (`src/c_api.zig:77-108`, `137-171`), enabling traps, stack over-read, and state underflow after a buggy callback. | Require `0 < result <= offered_len` before every slice or counter update; use checked addition. |
| E-02 | High | `advance_tx` reads `buffer[head]` before checking `len == 0` (`src/event.zig:123-125`). A valid zero-capacity C connection can access out of bounds when sent. | Check emptiness first and test zero-capacity send. |
| E-03 | Medium | Queue indices and length are `u16`, but the `usize` capacity limit is only a debug assertion (`src/queue.zig:7-26`); C accepts unrestricted `tx_node_count` (`src/c_api.zig:43-65`). | Use `usize` state or return an invalid-capacity error that survives release builds. |
| E-04 | High | C scalars/pointers are not recoverably validated. `@enumFromInt(opcode)` can receive values outside the `u4` domain, and `payload.?` traps when length is nonzero and the pointer is null (`src/c_api.zig:179-213`). | Validate opcode range/allowed values and every pointer-plus-length pair before conversion. |
| E-05 | Medium | The ABI exports sizes but not alignments, ships no C header, and immediately `@alignCast`s caller storage (`src/c_api.zig:32-65`; `build.zig:14-25`). | Install a versioned C header; export alignment queries or opaque create/init helpers; document storage extent and lifetime. |
| E-06 | Medium | `FrameNode` borrows payload memory until delayed transmission, and receive callbacks point into a temporary stack buffer (`src/event.zig:42-52`, `src/c_api.zig:87-108`, `143-171`). Neither lifetime is documented. | State that queued payload must remain live/immutable and callback payload must not be retained; prefer typed C declarations. |
| E-07 | Medium | The mask generator's four-byte output starts `undefined`; every nonnegative result is accepted without proving all bytes were initialized (`src/c_api.zig:194-201`). | Define one exact success result, initialize defensively, and require the callback to fill four bytes. |
| E-08 | Medium | Public cursor methods blindly add caller counts (`src/event.zig:114-120`, `134-141`), allowing header/payload state to exceed concrete slices. | Return errors for increments beyond the offered span and keep counters private where possible. |
| E-09 | Medium | Outbound construction accepts reserved opcodes, fragmented control frames, and control payloads over 125 bytes (`src/types.zig:1-15`, `src/event.zig:148-182`). | Apply the same opcode/control invariants used by decoding before serialization. |
| E-10 | Medium | Negative, EOF, and would-block callback results are collapsed into return `0`; successful full flush also returns `0` (`src/c_api.zig:73-127`, `130-176`). | Define stable result codes for progress, completion, would-block, EOF, callback failure, and protocol failure. |
| E-11 | Low | Completed TX nodes are skipped recursively (`src/event.zig:123-132`). Caller-constructed pre-completed nodes can create deep recursion. | Replace recursion with a loop. |
| E-12 | Low | `mask` computes `pos + 1..3` without wrapping checks; the C path casts a `u64` processed count to `usize`, which traps after 4 GiB on 32-bit targets (`src/frame.zig:13-21`, `src/c_api.zig:93-97`). | Rotate with `pos % 4` first and define/validate supported payload ranges per target. |
| E-13 | Low | Close payload length 1, close-code validity, close-reason UTF-8, and text-message UTF-8 are not validated. | Explicitly assign these to an application/message layer or implement them in connection state with tests. |

## Allocation and Leak Review

- Production files `src/frame.zig`, `src/queue.zig`, `src/event.zig`, and
  `src/c_api.zig` take no allocator and allocate no heap memory. Persistent
  storage is caller-backed; C receive/send uses fixed 4096-byte stack chunks.
- The two allocations in `src/test.zig:111-112` and `136-137` use
  `std.testing.allocator` and are paired with `defer free`. No static leak was
  found.
- The benchmark allocates one million `u64` latency values, approximately
  8 MiB, then timestamps and sorts all of them (`src/test.zig:103-203`). This is
  excessive for a unit-test target and can cause avoidable CI time or memory
  failures, but it is not leaked.
- Borrowed TX payloads can become dangling if callers free or mutate them
  before the queue drains. This is an ownership-contract defect, not an
  internally owned allocation leak.
- Dynamic leak detection was not run because the pinned Zig/Nix toolchain is
  unavailable in this environment. Therefore the conclusion is “no leak found
  statically,” not proof that every downstream integration is leak-free.

## Dead Code, Ghost Code, and Smells

- `PayloadMasked` and `PayloadNotMasked` are declared but never raised
  (`src/types.zig:37-46`). They are ghost error paths and evidence that mask
  policy was planned but not implemented.
- `const std = @import("std")` in `src/event.zig:1` is unused.
- `StatusCode`, `Queue.push_front`, and `Queue.pop_back` have no repository use
  sites. They are public API, so they are **unexercised**, not proven dead; add
  tests or remove them only through an API-version decision.
- `name` and `ext` are computed but unused by the release packaging loop
  (`.github/workflows/publish.yml:48-50`).
- `src/root.zig:30` still says `Conn` exposes callbacks, although the core now
  exposes actions. `src/c_api.zig:42` says initialization allocates even though
  it only initializes caller storage.
- No hidden executable feature, unreachable security-sensitive implementation,
  hardcoded credential, or production allocator path was found.

## Tests and Quality Gates

1. `zig build test` imports `src/root.zig`, not `src/c_api.zig`; C pointer,
   callback, chunk-boundary, alignment, and partial-I/O behavior is compiled but
   never executed (`src/test.zig:1-8`, `build.zig:14-43`). Add a C integration
   test or a Zig harness that calls every export with valid and invalid inputs.
2. The test named `Benchmark` performs one million timestamp operations and a
   full sort but has no performance assertion (`src/test.zig:103-203`). Move it
   behind an opt-in benchmark step and use bounded sampling.
3. The test named `Fuzz` is deterministic random testing, not coverage-guided
   fuzzing. It marks only the first two header bytes as read, so extended-header
   cases mostly return `need_header` without decoding (`src/test.zig:205-232`).
4. Missing regressions include encoder marker mismatches, zero-capacity queues,
   callback over-reporting/short reads, C frame completion, mask roles and RNG
   failure, RSV bits, fragment sequences, close payloads, and the untested deque
   directions.

No numeric coverage target is defined. Changed behavior should at minimum cover
every fixed invariant and its boundary values.

## Build, CI, and Supply-Chain Issues

- `flake.nix:30` silently falls back from Zig 0.16.0 to `pkgs.zig`, while the
  documentation claims an exact pin. The version helper also accepts any Zig
  0.16+ or 1.x (`.agents/skills/zig-0.16/scripts/check-zig-version.sh:12-20`).
- `cp -r zig-out/* ... || true` can let an empty package derivation succeed
  (`flake.nix:58-61`, `123-126`). Fail if the expected library is absent.
- The dev shell omits `pre-commit` (`flake.nix:32-43`), contradicting
  `CONTRIBUTE.md:71-91`; the documented hooks also differ from the actual
  `zig-fmt` and `zig-build-test` hooks (`.pre-commit-config.yaml:1-14`).
- `flake.lock` carries separate `nixpkgs` and `nixpkgs_2` inputs because the Zig
  overlay does not follow the root input (`flake.lock:68-123`). This increases
  closure/evaluation drift; wire `inputs.zig-overlay.inputs.nixpkgs.follows` if
  compatible.
- Pull-request tests are path-limited to Zig/ZON files
  (`.github/workflows/test.yml:7-12`); changes to `flake.nix`, `flake.lock`, or
  the workflow itself can evade this gate. Include all build and CI inputs.
- The release workflow neither validates tag versus `build.zig.zon` nor extracts
  matching changelog notes, despite `CI_CD_PIPELINE.md:45-67` and
  `CONTRIBUTE.md:109-117`. Add explicit validation before building or publishing.
- Lint/test/build jobs do not declare explicit read-only permissions. Add
  `permissions: contents: read` and grant write only to the final release job.
- Release builds use `ReleaseFast` (`flake.nix:45-57`, `115-126`) while
  `README.md:29` promises strict bounds-check resilience. Use `ReleaseSafe` for
  distributed parsing code or document and prove the selected safety model.

Configuration syntax checks passed for the shell helper, `.envrc`, all tracked
JSON files, all GitHub YAML files, and `.pre-commit-config.yaml`. No secret-like
credential material was identified. The Nix expressions could not be evaluated.

## Documentation and Agent-Guidance Drift

- `README.md:14` claims drop-in C ABI compatibility, but no C header is shipped;
  `README.md:29` overstates malicious-input safety in light of S-01 and
  `ReleaseFast`.
- `CI_CD_PIPELINE.md:20` says lint uses Nix, but the workflow uses
  `mlugg/setup-zig`; its version/changelog release steps do not exist.
- `CHANGELOG.md:11` claims dramatic cache/branch improvements without profiler
  evidence, and `CHANGELOG.md:53` incorrectly says main-push path filters apply.
- `CODING_CONVENTION.md:22` calls `root.zig` the C-FFI entry point; the actual
  library root is `src/c_api.zig`. Its mandatory `///` rule at lines 77-78
  conflicts with `.agents/skills/zslay-style/SKILL.md:15`, which forbids `///`.
- `CODING_CONVENTION.md` uses undefined citations such as `[4]`, `[6, 7]`, and
  `[8]`, and its function-pointer restriction conflicts with the public C
  callback design.
- Generic `.agents/skills/dod/SKILL.md:9-12` limits DoD to profiled internal C++
  paths, while the project-specific DoD guidance applies it to Zig public
  layouts. Clarify precedence or remove the irrelevant generic skill.
- `.agents/skills/zig-best-practices/C-INTEROP.md:14-75` recommends deprecated
  `@cImport` and `callconv(.C)`, conflicting with the Zig 0.16 guidance to use
  `addTranslateC` and `.c`.
- `.agents/skills/caveman/README.md:48` links to missing `.agents/README.md` via
  `../../README.md`. `.agents/skills/zig-testing/SKILL.md:262-265` references
  skill paths not present in this repository.
- The banner is a valid 920×320 PNG. Its XMP metadata contains Affinity 3.2.3
  and creation/modification timestamps; no author, GPS, email, or secret was
  found. Strip metadata only if reproducible/privacy-clean assets are desired.

## Recommended Remediation Order

1. Fix S-01 and E-01/E-02; add exact regression tests and run them in
   safety-enabled and release configurations.
2. Redesign the C receive contract around explicit chunk/frame completion,
   endpoint role, callback result validation, payload limits, stable status
   codes, and a published C header with size/alignment/lifetime rules.
3. Fail closed for masked frames, then add RSV, fragmentation, outbound control,
   and close-payload validation at clearly documented layers.
4. Pin CI actions, correct release validation, remove masked Nix install errors,
   and align the dev shell with documented hooks.
5. Move benchmark/fuzz work out of ordinary unit tests and reconcile all
   documentation and agent-skill contradictions.

## Verification and Limitations

Completed checks:

- Enumerated and reviewed all 55 tracked files at the fixed revision.
- Independently traced parser, queue, C ABI, masking, and CI trust boundaries.
- Parsed all JSON and YAML successfully.
- Ran Bash syntax checks on `.envrc` and the Zig-version helper.
- Inspected the PNG visually and reviewed its chunks/metadata.
- Searched for secrets, allocator use, unmatched allocations, dead identifiers,
  stale references, and common application vulnerability sinks.
- Completed a canonical repository security scan with 9 validated findings.

Unavailable checks: `zig`, `nix`, `zls`, `pre-commit`, CodeRabbit, Semgrep,
ShellCheck, Gitleaks, Trivy, Grype, Syft, OSV-Scanner, Zizmor, and Actionlint.
Accordingly, `zig build`, `zig build check`, `zig build test`, formatting,
runtime fuzzing, sanitizers, and dynamic leak detection were not executed.

## File-by-File Coverage

### Product Source

- `src/c_api.zig` — C ABI, callbacks, chunking, raw storage, masking, and lifetime findings.
- `src/event.zig` — RX/TX state, empty-queue access, recursion, limits, fragmentation, and borrowed payloads.
- `src/frame.zig` — encode bounds defect, decode validation, RSV/masking policy, and mask arithmetic.
- `src/queue.zig` — caller-backed deque, capacity representation, empty behavior, and untested directions.
- `src/root.zig` — public exports and stale callback description.
- `src/test.zig` — allocations, leak pairing, benchmark, random test, and coverage gaps.
- `src/types.zig` — layouts, non-exhaustive opcodes, status codes, and unused mask errors.

### Build and Repository Configuration

- `.envrc`
- `.gitignore`
- `.pre-commit-config.yaml`
- `build.zig`
- `build.zig.zon`
- `flake.lock`
- `flake.nix`
- `skills-lock.json`

These were checked for syntax, dependency/toolchain pinning, build outputs,
hooks, secrets, and drift. Findings are reported above; `.gitignore`, package
metadata, and skills hashes had no standalone defect.

### GitHub Configuration

- `.github/CODE_OF_CONDUCT.md`
- `.github/COMMIT_CONVENTION.md`
- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- `.github/ISSUE_TEMPLATE/security_vulnerability.yml`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/workflows/lint.yml`
- `.github/workflows/publish.yml`
- `.github/workflows/test.yml`

Templates and workflows were checked for disclosure routing, triggers,
permissions, dependency pinning, release integrity, and documentation agreement.

### Top-Level Documentation

- `AGENTS.md`
- `CHANGELOG.md`
- `CI_CD_PIPELINE.md`
- `CODEBASE.md`
- `CODING_CONVENTION.md`
- `CONTRIBUTE.md`
- `LICENSE`
- `README.md`
- `SECURITY.md`
- `SKILL.md`

The license and contributor/commit templates had no security defect. Accuracy,
broken claims, and policy conflicts are listed above.

### Agent Guidance

- `.agents/skills/caveman/README.md`
- `.agents/skills/caveman/SKILL.md`
- `.agents/skills/context7/SKILL.md`
- `.agents/skills/dod/SKILL.md`
- `.agents/skills/github-git/SKILL.md`
- `.agents/skills/nix-best-practices/SKILL.md`
- `.agents/skills/nix-hermetic/SKILL.md`
- `.agents/skills/ponytail/SKILL.md`
- `.agents/skills/pragmatic-functional-programming/SKILL.md`
- `.agents/skills/wslay-porting/SKILL.md`
- `.agents/skills/zig-0.16/SKILL.md`
- `.agents/skills/zig-0.16/scripts/check-zig-version.sh`
- `.agents/skills/zig-best-practices/C-INTEROP.md`
- `.agents/skills/zig-best-practices/DEBUGGING.md`
- `.agents/skills/zig-best-practices/GENERICS.md`
- `.agents/skills/zig-best-practices/SKILL.md`
- `.agents/skills/zig-testing/SKILL.md`
- `.agents/skills/zslay-c-ffi/SKILL.md`
- `.agents/skills/zslay-dod/SKILL.md`
- `.agents/skills/zslay-style/SKILL.md`

These files are development instructions, not production or CI runtime inputs.
Conflicts, stale API advice, missing references, and version-check drift are
reported above; no executable backdoor or embedded credential was found.

### Asset

- `misc/zslay-banner.png` — decoded and visually inspected; metadata result is
  documented above.
