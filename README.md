# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-23T08:33:33Z](https://github.com/farbenbuilds/zslay/actions/runs/39925153817) from [`eb3f7e2bae38`](https://github.com/farbenbuilds/zslay/commit/eb3f7e2bae382feab1ffbfd7f4bd8619578d2ff0); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.68 | 1,463,635,964 |
| `header_decode_masked` | 8 | 0.91 | 1,096,647,548 |
| `payload_mask_1024b` | 1,024 | 15.42 | 64,866,366 |
| `conn_rx_state_128b` | 136 | 8.05 | 124,158,362 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-23T08:33:33Z](https://github.com/farbenbuilds/zslay/actions/runs/39925153817) from [`eb3f7e2bae38`](https://github.com/farbenbuilds/zslay/commit/eb3f7e2bae382feab1ffbfd7f4bd8619578d2ff0); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 17,999 | 52.41 | 61.41 | 74.78 |
| 1 | 1,024 | 11,396 | 86.41 | 99.39 | 112.60 |
| 64 | 128 | 29,038 | 2,182.98 | 2,250.44 | 2,261.03 |
| 64 | 1,024 | 13,801 | 4,482.11 | 5,853.45 | 5,879.91 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-23T08:33:33Z | [`eb3f7e2bae38`](https://github.com/farbenbuilds/zslay/commit/eb3f7e2bae382feab1ffbfd7f4bd8619578d2ff0) | [JSON](records/2026/39925153817-1-eb3f7e2bae38.json) | [JSON](echo/records/2026/39925153817-1-eb3f7e2bae38.json) |
| 2026-10-22T08:36:34Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39748757985-1-2af3b092c186.json) | [JSON](echo/records/2026/39748757985-1-2af3b092c186.json) |
| 2026-10-21T08:34:07Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39570018615-1-2af3b092c186.json) | [JSON](echo/records/2026/39570018615-1-2af3b092c186.json) |
| 2026-10-20T08:31:50Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39393801586-1-2af3b092c186.json) | [JSON](echo/records/2026/39393801586-1-2af3b092c186.json) |
| 2026-10-19T08:51:44Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39225538977-1-2af3b092c186.json) | [JSON](echo/records/2026/39225538977-1-2af3b092c186.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
