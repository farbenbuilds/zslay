# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-14T08:43:09Z](https://github.com/farbenbuilds/zslay/actions/runs/38536858983) from [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.97 | 1,030,747,189 |
| `header_decode_masked` | 8 | 1.08 | 923,335,457 |
| `payload_mask_1024b` | 1,024 | 19.67 | 50,848,276 |
| `conn_rx_state_128b` | 136 | 13.41 | 74,542,144 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-14T08:43:09Z](https://github.com/farbenbuilds/zslay/actions/runs/38536858983) from [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 11,412 | 79.02 | 101.85 | 115.53 |
| 1 | 1,024 | 6,967 | 143.12 | 166.85 | 180.49 |
| 64 | 128 | 21,976 | 2,891.48 | 2,968.30 | 2,981.43 |
| 64 | 1,024 | 9,396 | 6,585.07 | 6,667.17 | 8,675.29 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-14T08:43:09Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38536858983-1-2af3b092c186.json) | [JSON](echo/records/2026/38536858983-1-2af3b092c186.json) |
| 2026-10-13T10:44:47Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38384101655-1-2af3b092c186.json) | [JSON](echo/records/2026/38384101655-1-2af3b092c186.json) |
| 2026-10-12T10:48:01Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38238387655-1-2af3b092c186.json) | [JSON](echo/records/2026/38238387655-1-2af3b092c186.json) |
| 2026-10-11T10:00:24Z | [`2af3b092c186`](https://github.com/farbenbuilds/zslay/commit/2af3b092c18655fc206b95689b859cea376b3de6) | [JSON](records/2026/38130273506-1-2af3b092c186.json) | [JSON](echo/records/2026/38130273506-1-2af3b092c186.json) |
| 2026-10-11T02:31:25Z | [`bb2a0c7abc01`](https://github.com/farbenbuilds/zslay/commit/bb2a0c7abc01274578af60a9e5b0f5c344d4754a) | [JSON](records/2026/38105320444-1-bb2a0c7abc01.json) | [JSON](echo/records/2026/38105320444-1-bb2a0c7abc01.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
