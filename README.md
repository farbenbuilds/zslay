# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-22T11:22:32Z](https://github.com/farbenbuilds/zslay/actions/runs/45016707831) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.92 | 1,086,413,315 |
| `header_decode_masked` | 8 | 6.30 | 158,823,184 |
| `payload_mask_1024b` | 1,024 | 19.70 | 50,775,030 |
| `conn_rx_state_128b` | 136 | 19.56 | 51,113,665 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-22T11:22:32Z](https://github.com/farbenbuilds/zslay/actions/runs/45016707831) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 12,015 | 77.64 | 98.41 | 137.67 |
| 1 | 1,024 | 7,121 | 124.27 | 154.17 | 174.16 |
| 64 | 128 | 20,548 | 3,097.19 | 3,243.88 | 3,271.09 |
| 64 | 1,024 | 9,673 | 6,353.20 | 6,543.05 | 6,607.94 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-22T11:22:32Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/45016707831-1-cad1c759c31b.json) | [JSON](echo/records/2026/45016707831-1-cad1c759c31b.json) |
| 2026-11-21T11:00:51Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44896802031-1-cad1c759c31b.json) | [JSON](echo/records/2026/44896802031-1-cad1c759c31b.json) |
| 2026-11-20T11:38:19Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44728767181-1-cad1c759c31b.json) | [JSON](echo/records/2026/44728767181-1-cad1c759c31b.json) |
| 2026-11-19T11:39:18Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44516268660-1-cad1c759c31b.json) | [JSON](echo/records/2026/44516268660-1-cad1c759c31b.json) |
| 2026-11-18T11:41:10Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44296431099-1-cad1c759c31b.json) | [JSON](echo/records/2026/44296431099-1-cad1c759c31b.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
