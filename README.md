# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-04T10:55:56Z](https://github.com/farbenbuilds/zslay/actions/runs/41817068615) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.54 | 648,504,225 |
| `header_decode_masked` | 8 | 1.44 | 695,705,411 |
| `payload_mask_1024b` | 1,024 | 34.34 | 29,120,737 |
| `conn_rx_state_128b` | 136 | 15.20 | 65,799,041 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-04T10:55:56Z](https://github.com/farbenbuilds/zslay/actions/runs/41817068615) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 12,305 | 79.97 | 105.22 | 118.82 |
| 1 | 1,024 | 6,505 | 153.20 | 181.03 | 195.39 |
| 64 | 128 | 19,924 | 3,194.53 | 3,286.87 | 3,520.36 |
| 64 | 1,024 | 7,425 | 7,840.07 | 9,897.48 | 9,999.49 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-04T10:55:56Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41817068615-1-0043f942169a.json) | [JSON](echo/records/2026/41817068615-1-0043f942169a.json) |
| 2026-11-03T10:53:24Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41622479242-1-0043f942169a.json) | [JSON](echo/records/2026/41622479242-1-0043f942169a.json) |
| 2026-11-02T11:03:06Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41433178448-1-0043f942169a.json) | [JSON](echo/records/2026/41433178448-1-0043f942169a.json) |
| 2026-11-01T10:28:26Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41297414824-1-0043f942169a.json) | [JSON](echo/records/2026/41297414824-1-0043f942169a.json) |
| 2026-10-31T09:40:26Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41189391639-1-0043f942169a.json) | [JSON](echo/records/2026/41189391639-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
