# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-26T08:55:10Z](https://github.com/farbenbuilds/zslay/actions/runs/40295279709) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.70 | 1,433,588,990 |
| `header_decode_masked` | 8 | 0.93 | 1,075,049,184 |
| `payload_mask_1024b` | 1,024 | 15.68 | 63,773,965 |
| `conn_rx_state_128b` | 136 | 8.24 | 121,285,039 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-26T08:55:11Z](https://github.com/farbenbuilds/zslay/actions/runs/40295279709) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 17,387 | 54.31 | 61.65 | 72.43 |
| 1 | 1,024 | 10,922 | 87.04 | 97.81 | 111.45 |
| 64 | 128 | 27,504 | 2,304.90 | 2,377.57 | 2,389.69 |
| 64 | 1,024 | 13,584 | 4,571.33 | 4,653.78 | 4,669.50 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-26T08:55:10Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/40295279709-1-0043f942169a.json) | [JSON](echo/records/2026/40295279709-1-0043f942169a.json) |
| 2026-10-25T08:26:59Z | [`eb3f7e2bae38`](https://github.com/farbenbuilds/zslay/commit/eb3f7e2bae382feab1ffbfd7f4bd8619578d2ff0) | [JSON](records/2026/40176406327-1-eb3f7e2bae38.json) | [JSON](echo/records/2026/40176406327-1-eb3f7e2bae38.json) |
| 2026-10-24T08:09:35Z | [`eb3f7e2bae38`](https://github.com/farbenbuilds/zslay/commit/eb3f7e2bae382feab1ffbfd7f4bd8619578d2ff0) | [JSON](records/2026/40076693438-1-eb3f7e2bae38.json) | [JSON](echo/records/2026/40076693438-1-eb3f7e2bae38.json) |
| 2026-10-23T08:33:33Z | [`eb3f7e2bae38`](https://github.com/farbenbuilds/zslay/commit/eb3f7e2bae382feab1ffbfd7f4bd8619578d2ff0) | [JSON](records/2026/39925153817-1-eb3f7e2bae38.json) | [JSON](echo/records/2026/39925153817-1-eb3f7e2bae38.json) |
| 2026-10-22T08:36:34Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39748757985-1-2af3b092c186.json) | [JSON](echo/records/2026/39748757985-1-2af3b092c186.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
