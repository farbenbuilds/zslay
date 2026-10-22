# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-22T08:36:34Z](https://github.com/farbenbuilds/zslay/actions/runs/39748757985) from [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.51 | 663,226,731 |
| `header_decode_masked` | 8 | 1.44 | 696,985,538 |
| `payload_mask_1024b` | 1,024 | 34.39 | 29,081,011 |
| `conn_rx_state_128b` | 136 | 15.26 | 65,546,348 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-22T08:36:34Z](https://github.com/farbenbuilds/zslay/actions/runs/39748757985) from [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 10,477 | 92.86 | 110.82 | 137.87 |
| 1 | 1,024 | 6,110 | 157.84 | 184.00 | 208.10 |
| 64 | 128 | 19,038 | 3,341.24 | 3,498.63 | 3,575.05 |
| 64 | 1,024 | 7,584 | 7,746.34 | 9,834.03 | 9,878.90 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-22T08:36:34Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39748757985-1-2af3b092c186.json) | [JSON](echo/records/2026/39748757985-1-2af3b092c186.json) |
| 2026-10-21T08:34:07Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39570018615-1-2af3b092c186.json) | [JSON](echo/records/2026/39570018615-1-2af3b092c186.json) |
| 2026-10-20T08:31:50Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39393801586-1-2af3b092c186.json) | [JSON](echo/records/2026/39393801586-1-2af3b092c186.json) |
| 2026-10-19T08:51:44Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39225538977-1-2af3b092c186.json) | [JSON](echo/records/2026/39225538977-1-2af3b092c186.json) |
| 2026-10-18T08:01:48Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39109724368-1-2af3b092c186.json) | [JSON](echo/records/2026/39109724368-1-2af3b092c186.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
