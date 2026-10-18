# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-18T08:01:48Z](https://github.com/farbenbuilds/zslay/actions/runs/39109724368) from [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.93 | 1,080,812,339 |
| `header_decode_masked` | 8 | 2.16 | 463,340,500 |
| `payload_mask_1024b` | 1,024 | 22.97 | 43,529,777 |
| `conn_rx_state_128b` | 136 | 18.33 | 54,562,220 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-18T08:01:48Z](https://github.com/farbenbuilds/zslay/actions/runs/39109724368) from [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 7,118 | 156.11 | 178.29 | 198.22 |
| 1 | 1,024 | 4,713 | 207.08 | 252.12 | 276.65 |
| 64 | 128 | 14,510 | 4,383.55 | 4,558.99 | 5,014.51 |
| 64 | 1,024 | 6,354 | 9,300.42 | 12,255.74 | 12,370.30 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-18T08:01:48Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39109724368-1-2af3b092c186.json) | [JSON](echo/records/2026/39109724368-1-2af3b092c186.json) |
| 2026-10-17T07:48:07Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/39014858157-1-2af3b092c186.json) | [JSON](echo/records/2026/39014858157-1-2af3b092c186.json) |
| 2026-10-16T08:10:40Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38871717682-1-2af3b092c186.json) | [JSON](echo/records/2026/38871717682-1-2af3b092c186.json) |
| 2026-10-15T08:18:18Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38704453667-1-2af3b092c186.json) | [JSON](echo/records/2026/38704453667-1-2af3b092c186.json) |
| 2026-10-14T08:43:09Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38536858983-1-2af3b092c186.json) | [JSON](echo/records/2026/38536858983-1-2af3b092c186.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
