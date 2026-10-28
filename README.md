# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-28T09:41:19Z](https://github.com/farbenbuilds/zslay/actions/runs/40665701101) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.05 | 953,870,808 |
| `header_decode_masked` | 8 | 2.16 | 463,361,969 |
| `payload_mask_1024b` | 1,024 | 22.82 | 43,829,526 |
| `conn_rx_state_128b` | 136 | 18.00 | 55,561,914 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-28T09:41:20Z](https://github.com/farbenbuilds/zslay/actions/runs/40665701101) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 7,724 | 116.68 | 141.54 | 164.08 |
| 1 | 1,024 | 4,858 | 183.73 | 227.76 | 246.81 |
| 64 | 128 | 15,162 | 4,156.45 | 4,264.33 | 4,709.14 |
| 64 | 1,024 | 6,830 | 8,994.13 | 11,931.34 | 12,032.36 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-28T09:41:19Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40665701101-1-0043f942169a.json) | [JSON](echo/records/2026/40665701101-1-0043f942169a.json) |
| 2026-10-27T09:00:32Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40477154431-1-0043f942169a.json) | [JSON](echo/records/2026/40477154431-1-0043f942169a.json) |
| 2026-10-26T08:55:10Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40295279709-1-0043f942169a.json) | [JSON](echo/records/2026/40295279709-1-0043f942169a.json) |
| 2026-10-25T08:26:59Z | [`eb3f7e2bae38`](https://github.com/farbenbuilds/zslay/commit/eb3f7e2bae382feab1ffbfd7f4bd8619578d2ff0) | [JSON](records/2026/40176406327-1-eb3f7e2bae38.json) | [JSON](echo/records/2026/40176406327-1-eb3f7e2bae38.json) |
| 2026-10-24T08:09:35Z | [`eb3f7e2bae38`](https://github.com/farbenbuilds/zslay/commit/eb3f7e2bae382feab1ffbfd7f4bd8619578d2ff0) | [JSON](records/2026/40076693438-1-eb3f7e2bae38.json) | [JSON](echo/records/2026/40076693438-1-eb3f7e2bae38.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
