# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-29T09:59:40Z](https://github.com/farbenbuilds/zslay/actions/runs/40853492074) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.04 | 960,947,109 |
| `header_decode_masked` | 8 | 2.27 | 440,482,064 |
| `payload_mask_1024b` | 1,024 | 22.79 | 43,889,062 |
| `conn_rx_state_128b` | 136 | 17.80 | 56,176,241 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-29T09:59:40Z](https://github.com/farbenbuilds/zslay/actions/runs/40853492074) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 8,443 | 104.58 | 159.61 | 185.24 |
| 1 | 1,024 | 5,188 | 174.34 | 226.88 | 237.19 |
| 64 | 128 | 13,617 | 4,472.98 | 4,605.02 | 4,909.09 |
| 64 | 1,024 | 6,736 | 9,013.75 | 9,266.35 | 9,436.53 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-29T09:59:40Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40853492074-1-0043f942169a.json) | [JSON](echo/records/2026/40853492074-1-0043f942169a.json) |
| 2026-10-28T09:41:19Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40665701101-1-0043f942169a.json) | [JSON](echo/records/2026/40665701101-1-0043f942169a.json) |
| 2026-10-27T09:00:32Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40477154431-1-0043f942169a.json) | [JSON](echo/records/2026/40477154431-1-0043f942169a.json) |
| 2026-10-26T08:55:10Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40295279709-1-0043f942169a.json) | [JSON](echo/records/2026/40295279709-1-0043f942169a.json) |
| 2026-10-25T08:26:59Z | [`eb3f7e2bae38`](https://github.com/farbenbuilds/zslay/commit/eb3f7e2bae382feab1ffbfd7f4bd8619578d2ff0) | [JSON](records/2026/40176406327-1-eb3f7e2bae38.json) | [JSON](echo/records/2026/40176406327-1-eb3f7e2bae38.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
