# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-15T08:18:18Z](https://github.com/farbenbuilds/zslay/actions/runs/38704453667) from [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.96 | 1,040,810,167 |
| `header_decode_masked` | 8 | 1.85 | 540,525,932 |
| `payload_mask_1024b` | 1,024 | 23.24 | 43,024,928 |
| `conn_rx_state_128b` | 136 | 18.38 | 54,401,163 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-15T08:18:18Z](https://github.com/farbenbuilds/zslay/actions/runs/38704453667) from [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 7,433 | 118.34 | 169.49 | 187.53 |
| 1 | 1,024 | 4,749 | 208.57 | 248.63 | 265.29 |
| 64 | 128 | 15,280 | 4,142.37 | 4,239.76 | 4,353.22 |
| 64 | 1,024 | 6,878 | 8,799.15 | 9,445.50 | 11,885.90 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-15T08:18:18Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38704453667-1-2af3b092c186.json) | [JSON](echo/records/2026/38704453667-1-2af3b092c186.json) |
| 2026-10-14T08:43:09Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38536858983-1-2af3b092c186.json) | [JSON](echo/records/2026/38536858983-1-2af3b092c186.json) |
| 2026-10-13T10:44:47Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38384101655-1-2af3b092c186.json) | [JSON](echo/records/2026/38384101655-1-2af3b092c186.json) |
| 2026-10-12T10:48:01Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38238387655-1-2af3b092c186.json) | [JSON](echo/records/2026/38238387655-1-2af3b092c186.json) |
| 2026-10-11T10:00:24Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38130273506-1-2af3b092c186.json) | [JSON](echo/records/2026/38130273506-1-2af3b092c186.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
