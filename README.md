# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-03T10:53:24Z](https://github.com/farbenbuilds/zslay/actions/runs/41622479242) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.04 | 960,854,776 |
| `header_decode_masked` | 8 | 2.16 | 463,342,647 |
| `payload_mask_1024b` | 1,024 | 22.70 | 44,063,423 |
| `conn_rx_state_128b` | 136 | 17.84 | 56,059,185 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-03T10:53:24Z](https://github.com/farbenbuilds/zslay/actions/runs/41622479242) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 9,165 | 96.19 | 138.05 | 160.57 |
| 1 | 1,024 | 5,705 | 162.84 | 213.22 | 240.99 |
| 64 | 128 | 15,218 | 4,172.28 | 4,288.52 | 4,491.01 |
| 64 | 1,024 | 6,323 | 9,240.10 | 11,946.31 | 11,991.52 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-03T10:53:24Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41622479242-1-0043f942169a.json) | [JSON](echo/records/2026/41622479242-1-0043f942169a.json) |
| 2026-11-02T11:03:06Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41433178448-1-0043f942169a.json) | [JSON](echo/records/2026/41433178448-1-0043f942169a.json) |
| 2026-11-01T10:28:26Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41297414824-1-0043f942169a.json) | [JSON](echo/records/2026/41297414824-1-0043f942169a.json) |
| 2026-10-31T09:40:26Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41189391639-1-0043f942169a.json) | [JSON](echo/records/2026/41189391639-1-0043f942169a.json) |
| 2026-10-30T10:01:32Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41037265882-1-0043f942169a.json) | [JSON](echo/records/2026/41037265882-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
