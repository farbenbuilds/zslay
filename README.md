# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-25T12:52:33Z](https://github.com/farbenbuilds/zslay/actions/runs/45617472491) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.16 | 861,935,217 |
| `header_decode_masked` | 8 | 5.69 | 175,619,762 |
| `payload_mask_1024b` | 1,024 | 19.30 | 51,824,588 |
| `conn_rx_state_128b` | 136 | 13.46 | 74,285,927 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-25T12:52:33Z](https://github.com/farbenbuilds/zslay/actions/runs/45617472491) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 14,351 | 75.74 | 88.48 | 97.41 |
| 1 | 1,024 | 9,899 | 101.63 | 117.78 | 129.74 |
| 64 | 128 | 27,522 | 2,396.40 | 2,505.00 | 2,531.89 |
| 64 | 1,024 | 13,623 | 4,486.11 | 5,361.94 | 5,472.73 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-25T12:52:33Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45617472491-1-cad1c759c31b.json) | [JSON](echo/records/2026/45617472491-1-cad1c759c31b.json) |
| 2026-11-24T13:43:09Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45405667926-1-cad1c759c31b.json) | [JSON](echo/records/2026/45405667926-1-cad1c759c31b.json) |
| 2026-11-23T12:36:32Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45175284343-1-cad1c759c31b.json) | [JSON](echo/records/2026/45175284343-1-cad1c759c31b.json) |
| 2026-11-22T11:22:32Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45016707831-1-cad1c759c31b.json) | [JSON](echo/records/2026/45016707831-1-cad1c759c31b.json) |
| 2026-11-21T11:00:51Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44896802031-1-cad1c759c31b.json) | [JSON](echo/records/2026/44896802031-1-cad1c759c31b.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
