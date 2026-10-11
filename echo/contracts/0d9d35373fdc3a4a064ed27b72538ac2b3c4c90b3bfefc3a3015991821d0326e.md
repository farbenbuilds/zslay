# WebSocket echo benchmark contract

`zslay-echo` measures complete binary WebSocket echo round trips over loopback TCP. The server is a small socket adapter around zslay's public C ABI; the independent Python standard-library client performs the HTTP upgrade, writes masked WebSocket frames, and validates each unmasked echo. This suite includes transport, scheduling, callback, and client overhead. It complements the [in-process core benchmark](CONTRACT.md); its rates are a separate series and must not be compared with core `ops_per_sec`.

## Fixed workload

| Connections | Payload per binary message | Warmup | Timed repetitions |
| ---: | ---: | ---: | ---: |
| 1 | 128 bytes | 1 second | 3 x 5 seconds |
| 1 | 1024 bytes | 1 second | 3 x 5 seconds |
| 64 | 128 bytes | 1 second | 3 x 5 seconds |
| 64 | 1024 bytes | 1 second | 3 x 5 seconds |

Each connection sends one request at a time and waits for its echo before sending the next. Connections are opened and their WebSocket upgrades checked before timing starts. Each timed repetition uses fresh connections. The server enables `TCP_NODELAY` on accepted sockets. The client rejects an invalid upgrade response, an unexpected opcode or mask bit, and any echo whose length or content differs from the sent payload. Client messages use a fresh random masking key. A warmup or timed sample fails if it completes no echoes or records any errors. The adapter limits messages to 4096 bytes and concurrent clients to 128; the fixed matrix stays below both limits.

An operation is one successfully validated request-and-echo pair, not one frame or one direction of traffic. `ops_per_sec` is completed operations divided by measured seconds, with the median of three repetition rates reported for each case. `rtt_ns` contains p50, p95, and p99 request-to-echo times from up to 4096 recent completed operations per repetition; the case-level percentiles are medians of the three repetition percentiles. Raw repetition durations, operation counts, errors, rates, and latency percentiles are retained in the JSON. Timing includes client masking, socket I/O, server processing, and response validation; it excludes connection setup and JSON writing. These are local end-to-end measurements, not standalone zslay parser timings.

Changing the workload, protocol checks, or measurement method requires a new contract version and benchmark identity so incompatible results do not share one history series.

## Run locally

From the repository root, enter the pinned development shell and build the adapter:

```sh
nix develop
zig build bench-echo -Doptimize=ReleaseFast
zig-out/bin/zslay-echo-server --port 9001
```

The server prints `READY 9001` when it is listening. In another shell, run the fixed matrix:

```sh
python3 scripts/benchmark_echo.py --port 9001 \
  --case 1:128 --case 1:1024 --case 64:128 --case 64:1024 \
  --duration 5 --warmup 1 --output echo.json
```

The client uses only Python's standard library; no WebSocket package is involved. The adapter is a benchmark harness, not a production HTTP or WebSocket server.

## CI and history

The [benchmark workflow](../.github/workflows/benchmark.yml) runs the fixed echo matrix alongside the core suite on benchmark-relevant pull requests, nightly `main` runs, and manual runs. Pull-request artifacts contain the echo candidate result and, when the base revision has a compatible echo suite, its result and an advisory per-case operations-per-second ratio. Both revisions run on the same runner. There is no pass/fail performance threshold. Pull-request code has read-only permissions.

On scheduled and manually dispatched `main` runs, a separate bot job publishes validated results to the `benchmark-data` branch. Echo data has its own `echo/records/YYYY/` immutable records, `echo/contracts/` content-addressed contract snapshots, `echo/index.json`, and `echo/latest.json`. Each record carries source revision, run metadata, runner and toolchain details, raw samples, and the checksum of this contract. Core results remain in the branch root; the two histories are separate.

The bot-generated [results README](https://github.com/farbenbuilds/zslay/tree/benchmark-data) displays the latest echo cases and recent runs alongside the separate core suite. Its links lead to `echo/latest.json`, immutable records, and this workload contract for complete results.

GitHub-hosted runners vary in CPU model, load, and scheduling. Interpret trends within matching hardware and toolchain cohorts. The numbers describe this one loopback adapter and client workload; they do not rank WebSocket frameworks or claim public-network capacity.
