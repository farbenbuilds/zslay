# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-30T10:01:32Z](https://github.com/farbenbuilds/zslay/actions/runs/41037265882) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.91 | 1,094,391,245 |
| `header_decode_masked` | 8 | 1.08 | 923,361,034 |
| `payload_mask_1024b` | 1,024 | 19.72 | 50,714,002 |
| `conn_rx_state_128b` | 136 | 13.03 | 76,724,243 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-30T10:01:32Z](https://github.com/farbenbuilds/zslay/actions/runs/41037265882) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 12,899 | 71.30 | 95.06 | 107.37 |
| 1 | 1,024 | 7,298 | 147.31 | 168.86 | 175.36 |
| 64 | 128 | 22,052 | 2,886.75 | 2,918.26 | 2,949.45 |
| 64 | 1,024 | 9,429 | 6,551.26 | 6,666.61 | 6,702.26 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-30T10:01:32Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/41037265882-1-0043f942169a.json) | [JSON](echo/records/2026/41037265882-1-0043f942169a.json) |
| 2026-10-29T09:59:40Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40853492074-1-0043f942169a.json) | [JSON](echo/records/2026/40853492074-1-0043f942169a.json) |
| 2026-10-28T09:41:19Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40665701101-1-0043f942169a.json) | [JSON](echo/records/2026/40665701101-1-0043f942169a.json) |
| 2026-10-27T09:00:32Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40477154431-1-0043f942169a.json) | [JSON](echo/records/2026/40477154431-1-0043f942169a.json) |
| 2026-10-26T08:55:10Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40295279709-1-0043f942169a.json) | [JSON](echo/records/2026/40295279709-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
