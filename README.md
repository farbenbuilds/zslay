# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-28T11:44:29Z](https://github.com/farbenbuilds/zslay/actions/runs/46141049003) from [`5a3dd8e713d6`](https://github.com/farbenbuilds/zslay/commit/5a3dd8e713d63dc164fb54097136c66723b9d9d3); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.32 | 756,097,930 |
| `header_decode_masked` | 8 | 6.54 | 152,977,711 |
| `payload_mask_1024b` | 1,024 | 21.97 | 45,514,148 |
| `conn_rx_state_128b` | 136 | 15.97 | 62,597,104 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-28T11:44:29Z](https://github.com/farbenbuilds/zslay/actions/runs/46141049003) from [`5a3dd8e713d6`](https://github.com/farbenbuilds/zslay/commit/5a3dd8e713d63dc164fb54097136c66723b9d9d3); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 13,259 | 79.88 | 91.91 | 98.81 |
| 1 | 1,024 | 8,452 | 119.50 | 135.45 | 145.24 |
| 64 | 128 | 24,191 | 2,629.72 | 2,684.21 | 2,898.52 |
| 64 | 1,024 | 11,364 | 5,591.92 | 5,650.00 | 5,680.78 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-28T11:44:29Z | [`5a3dd8e713d6`](https://github.com/farbenbuilds/zslay/commit/5a3dd8e713d63dc164fb54097136c66723b9d9d3) | [JSON](records/2026/46141049003-1-5a3dd8e713d6.json) | [JSON](echo/records/2026/46141049003-1-5a3dd8e713d6.json) |
| 2026-11-27T12:16:20Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45996793322-1-cad1c759c31b.json) | [JSON](echo/records/2026/45996793322-1-cad1c759c31b.json) |
| 2026-11-26T12:36:33Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45819911204-1-cad1c759c31b.json) | [JSON](echo/records/2026/45819911204-1-cad1c759c31b.json) |
| 2026-11-25T12:52:33Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45617472491-1-cad1c759c31b.json) | [JSON](echo/records/2026/45617472491-1-cad1c759c31b.json) |
| 2026-11-24T13:43:09Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45405667926-1-cad1c759c31b.json) | [JSON](echo/records/2026/45405667926-1-cad1c759c31b.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
