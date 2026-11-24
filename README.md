# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-24T13:43:09Z](https://github.com/farbenbuilds/zslay/actions/runs/45405667926) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.23 | 810,819,576 |
| `header_decode_masked` | 8 | 9.38 | 106,652,219 |
| `payload_mask_1024b` | 1,024 | 22.92 | 43,637,290 |
| `conn_rx_state_128b` | 136 | 27.03 | 36,990,388 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-24T13:43:10Z](https://github.com/farbenbuilds/zslay/actions/runs/45405667926) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 9,674 | 90.11 | 140.54 | 158.45 |
| 1 | 1,024 | 6,316 | 147.23 | 192.66 | 211.40 |
| 64 | 128 | 16,595 | 3,849.48 | 4,076.78 | 4,525.29 |
| 64 | 1,024 | 7,503 | 8,144.62 | 10,916.89 | 10,939.65 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-24T13:43:09Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45405667926-1-cad1c759c31b.json) | [JSON](echo/records/2026/45405667926-1-cad1c759c31b.json) |
| 2026-11-23T12:36:32Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45175284343-1-cad1c759c31b.json) | [JSON](echo/records/2026/45175284343-1-cad1c759c31b.json) |
| 2026-11-22T11:22:32Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45016707831-1-cad1c759c31b.json) | [JSON](echo/records/2026/45016707831-1-cad1c759c31b.json) |
| 2026-11-21T11:00:51Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44896802031-1-cad1c759c31b.json) | [JSON](echo/records/2026/44896802031-1-cad1c759c31b.json) |
| 2026-11-20T11:38:19Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44728767181-1-cad1c759c31b.json) | [JSON](echo/records/2026/44728767181-1-cad1c759c31b.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
