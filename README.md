# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-05T10:58:45Z](https://github.com/farbenbuilds/zslay/actions/runs/42014146352) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.04 | 960,660,935 |
| `header_decode_masked` | 8 | 2.17 | 461,691,175 |
| `payload_mask_1024b` | 1,024 | 22.43 | 44,584,241 |
| `conn_rx_state_128b` | 136 | 17.75 | 56,325,335 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-05T10:58:45Z](https://github.com/farbenbuilds/zslay/actions/runs/42014146352) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 9,353 | 110.80 | 151.20 | 169.05 |
| 1 | 1,024 | 5,731 | 161.64 | 215.45 | 243.01 |
| 64 | 128 | 15,464 | 4,115.43 | 4,220.32 | 4,323.81 |
| 64 | 1,024 | 6,526 | 11,405.19 | 11,545.24 | 11,568.08 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-05T10:58:45Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42014146352-1-0043f942169a.json) | [JSON](echo/records/2026/42014146352-1-0043f942169a.json) |
| 2026-11-04T10:55:56Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41817068615-1-0043f942169a.json) | [JSON](echo/records/2026/41817068615-1-0043f942169a.json) |
| 2026-11-03T10:53:24Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41622479242-1-0043f942169a.json) | [JSON](echo/records/2026/41622479242-1-0043f942169a.json) |
| 2026-11-02T11:03:06Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41433178448-1-0043f942169a.json) | [JSON](echo/records/2026/41433178448-1-0043f942169a.json) |
| 2026-11-01T10:28:26Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41297414824-1-0043f942169a.json) | [JSON](echo/records/2026/41297414824-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
