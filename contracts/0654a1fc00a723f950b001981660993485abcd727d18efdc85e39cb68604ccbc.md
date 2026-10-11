# WebSocket core benchmark contract

`zslay-core` measures operations within the Zig WebSocket framing library. It does not start a server, open sockets, include transport I/O, or measure end-to-end WebSocket throughput. Case definitions and fixed workloads live in `src/bench.zig`; the runner emits one JSON object on standard output. Change the schema version and benchmark identity when changing a workload or its measurement method, so incompatible results do not share a history series.

For real loopback socket round trips, see the separate [echo benchmark contract](ECHO_CONTRACT.md). Core and echo rates measure different work and belong to separate history namespaces.

## Cases and units

| Case | Operation counted | `bytes_per_op` |
| --- | --- | ---: |
| `header_encode_masked` | Encode a masked 128-byte binary frame header into caller-owned storage. | 8 |
| `header_decode_masked` | Decode that masked header. | 8 |
| `payload_mask_1024b` | XOR-mask a caller-owned 1 KiB payload in place. | 1024 |
| `conn_rx_state_128b` | Advance a server `Conn` through receive header and payload state transitions for a 128-byte frame. | 136 |

`bytes_per_op` describes workload size, not network bytes transferred. The receive-state value counts an 8-byte header plus 128 payload bytes, although the operation only advances the payload counter and does not copy payload bytes. Compare rates within the same case only; a header operation and a payload operation have different work.

The runner performs 10,000 warmup operations per case, then seven timed batches of 100,000 operations. Each batch duration is recorded as `sample_durations_ns`. The median batch duration divided by 100,000 is `ns_per_op`; `ops_per_sec` is derived as `1,000,000,000 / ns_per_op`. `samples_ns_per_op` retains each batch's time per operation. The timed loop includes operation-level consistency checks; setup and JSON formatting are outside the timed batches. The JSON also contains `schema_version`, `benchmark`, `warmup_operations`, `iterations_per_sample`, and `repetitions`.

## Run locally

From the repository root, enter the pinned Nix development shell and run:

```sh
nix develop
zig build bench -Doptimize=ReleaseFast
```

The benchmark executable is built with Zig `ReleaseFast` for performance measurement. Distributed library builds use their own `ReleaseSafe` settings. The command writes machine-readable JSON to standard output. Do not compare this benchmark's numbers with results from the old multi-session ping/pong benchmark; the measured work is different.

## CI and durable history

The [benchmark workflow](../.github/workflows/benchmark.yml) runs the suite on pull requests, scheduled `main` runs, and manual dispatch. Pull requests receive a workflow artifact containing the candidate result and, when compatible, a same-run base comparison. That comparison is advisory; it is not a performance gate. Pull-request jobs have no history-branch write permission.

Scheduled and manually dispatched runs on `main` publish through a separate bot job to the `benchmark-data` branch. The branch holds immutable `records/YYYY/<record-id>.json` files, content-addressed `contracts/<sha256>.md` snapshots, a full `latest.json` record, and an `index.json` of record IDs, paths, timestamps, and source revisions. Each record includes the contract checksum, source SHA, GitHub run metadata, runner image, CPU, kernel, Zig version, and flake-lock hash alongside raw samples. Publishing the same record again is idempotent; a conflicting record ID is an error. See [CI/CD pipeline](../CI_CD_PIPELINE.md) for workflow triggers and permissions.

The bot-generated [results README](https://github.com/farbenbuilds/zslay/tree/benchmark-data) summarizes the latest core cases and recent runs alongside the separate echo suite. Follow its links to `latest.json`, immutable records, and the workload contract for complete results.

GitHub-hosted runner hardware and scheduling vary. These measurements are useful for tracking core operations, but absolute rates from different machines or toolchain cohorts are not directly comparable. Use matching case definitions and environment metadata when reading trends. A scheduled run against `main` is a control point in the long-term series, not a fixed hardware capacity claim.
