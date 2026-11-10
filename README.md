# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-10T11:11:35Z](https://github.com/farbenbuilds/zslay/actions/runs/42804965813) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.92 | 1,086,413,315 |
| `header_decode_masked` | 8 | 1.08 | 923,361,034 |
| `payload_mask_1024b` | 1,024 | 19.79 | 50,539,637 |
| `conn_rx_state_128b` | 136 | 13.03 | 76,753,629 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-10T11:11:36Z](https://github.com/farbenbuilds/zslay/actions/runs/42804965813) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 12,729 | 90.02 | 103.41 | 115.74 |
| 1 | 1,024 | 7,384 | 130.83 | 161.25 | 175.32 |
| 64 | 128 | 21,859 | 2,911.14 | 2,965.99 | 3,039.03 |
| 64 | 1,024 | 8,940 | 8,391.83 | 8,608.47 | 9,402.26 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-10T11:11:35Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42804965813-1-0043f942169a.json) | [JSON](echo/records/2026/42804965813-1-0043f942169a.json) |
| 2026-11-09T11:31:16Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42609202431-1-0043f942169a.json) | [JSON](echo/records/2026/42609202431-1-0043f942169a.json) |
| 2026-11-08T10:20:24Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42470788038-1-0043f942169a.json) | [JSON](echo/records/2026/42470788038-1-0043f942169a.json) |
| 2026-11-07T10:07:02Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42362307220-1-0043f942169a.json) | [JSON](echo/records/2026/42362307220-1-0043f942169a.json) |
| 2026-11-06T10:53:09Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42205628131-1-0043f942169a.json) | [JSON](echo/records/2026/42205628131-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
