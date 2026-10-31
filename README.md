# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-31T09:40:26Z](https://github.com/farbenbuilds/zslay/actions/runs/41189391639) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.04 | 960,864,009 |
| `header_decode_masked` | 8 | 2.16 | 463,346,940 |
| `payload_mask_1024b` | 1,024 | 22.61 | 44,230,976 |
| `conn_rx_state_128b` | 136 | 17.79 | 56,222,606 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-31T09:40:26Z](https://github.com/farbenbuilds/zslay/actions/runs/41189391639) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 9,065 | 98.27 | 152.05 | 170.15 |
| 1 | 1,024 | 5,764 | 165.71 | 228.09 | 257.78 |
| 64 | 128 | 14,790 | 4,266.43 | 4,442.62 | 4,675.93 |
| 64 | 1,024 | 6,593 | 9,165.83 | 12,206.30 | 12,259.86 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-31T09:40:26Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41189391639-1-0043f942169a.json) | [JSON](echo/records/2026/41189391639-1-0043f942169a.json) |
| 2026-10-30T10:01:32Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41037265882-1-0043f942169a.json) | [JSON](echo/records/2026/41037265882-1-0043f942169a.json) |
| 2026-10-29T09:59:40Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40853492074-1-0043f942169a.json) | [JSON](echo/records/2026/40853492074-1-0043f942169a.json) |
| 2026-10-28T09:41:19Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40665701101-1-0043f942169a.json) | [JSON](echo/records/2026/40665701101-1-0043f942169a.json) |
| 2026-10-27T09:00:32Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40477154431-1-0043f942169a.json) | [JSON](echo/records/2026/40477154431-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
