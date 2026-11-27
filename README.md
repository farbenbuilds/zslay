# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-27T12:16:20Z](https://github.com/farbenbuilds/zslay/actions/runs/45996793322) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.68 | 1,480,341,071 |
| `header_decode_masked` | 8 | 3.88 | 257,788,433 |
| `payload_mask_1024b` | 1,024 | 15.22 | 65,704,792 |
| `conn_rx_state_128b` | 136 | 12.18 | 82,103,154 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-27T12:16:20Z](https://github.com/farbenbuilds/zslay/actions/runs/45996793322) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 17,362 | 51.41 | 63.27 | 71.34 |
| 1 | 1,024 | 11,884 | 81.42 | 96.43 | 105.21 |
| 64 | 128 | 28,758 | 2,202.89 | 2,258.60 | 2,942.99 |
| 64 | 1,024 | 15,255 | 4,102.77 | 4,218.24 | 4,259.82 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-27T12:16:20Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45996793322-1-cad1c759c31b.json) | [JSON](echo/records/2026/45996793322-1-cad1c759c31b.json) |
| 2026-11-26T12:36:33Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45819911204-1-cad1c759c31b.json) | [JSON](echo/records/2026/45819911204-1-cad1c759c31b.json) |
| 2026-11-25T12:52:33Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45617472491-1-cad1c759c31b.json) | [JSON](echo/records/2026/45617472491-1-cad1c759c31b.json) |
| 2026-11-24T13:43:09Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45405667926-1-cad1c759c31b.json) | [JSON](echo/records/2026/45405667926-1-cad1c759c31b.json) |
| 2026-11-23T12:36:32Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45175284343-1-cad1c759c31b.json) | [JSON](echo/records/2026/45175284343-1-cad1c759c31b.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
