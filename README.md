# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-06T10:53:09Z](https://github.com/farbenbuilds/zslay/actions/runs/42205628131) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.91 | 1,094,343,339 |
| `header_decode_masked` | 8 | 1.08 | 923,326,932 |
| `payload_mask_1024b` | 1,024 | 19.71 | 50,724,858 |
| `conn_rx_state_128b` | 136 | 13.16 | 75,991,364 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-06T10:53:09Z](https://github.com/farbenbuilds/zslay/actions/runs/42205628131) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 12,780 | 74.11 | 100.36 | 114.72 |
| 1 | 1,024 | 7,336 | 133.58 | 165.88 | 178.35 |
| 64 | 128 | 21,613 | 2,931.45 | 3,008.53 | 3,794.89 |
| 64 | 1,024 | 9,093 | 6,713.44 | 8,538.62 | 8,685.91 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-06T10:53:09Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42205628131-1-0043f942169a.json) | [JSON](echo/records/2026/42205628131-1-0043f942169a.json) |
| 2026-11-05T10:58:45Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42014146352-1-0043f942169a.json) | [JSON](echo/records/2026/42014146352-1-0043f942169a.json) |
| 2026-11-04T10:55:56Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41817068615-1-0043f942169a.json) | [JSON](echo/records/2026/41817068615-1-0043f942169a.json) |
| 2026-11-03T10:53:24Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41622479242-1-0043f942169a.json) | [JSON](echo/records/2026/41622479242-1-0043f942169a.json) |
| 2026-11-02T11:03:06Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41433178448-1-0043f942169a.json) | [JSON](echo/records/2026/41433178448-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
