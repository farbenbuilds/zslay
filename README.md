# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-21T11:00:51Z](https://github.com/farbenbuilds/zslay/actions/runs/44896802031) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.67 | 1,501,704,435 |
| `header_decode_masked` | 8 | 3.88 | 257,920,746 |
| `payload_mask_1024b` | 1,024 | 14.87 | 67,245,109 |
| `conn_rx_state_128b` | 136 | 11.82 | 84,566,811 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-21T11:00:52Z](https://github.com/farbenbuilds/zslay/actions/runs/44896802031) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 19,021 | 49.24 | 57.39 | 65.59 |
| 1 | 1,024 | 12,602 | 80.82 | 92.19 | 99.58 |
| 64 | 128 | 29,551 | 2,054.89 | 2,098.01 | 2,239.64 |
| 64 | 1,024 | 16,851 | 3,769.30 | 3,815.72 | 3,829.07 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-21T11:00:51Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44896802031-1-cad1c759c31b.json) | [JSON](echo/records/2026/44896802031-1-cad1c759c31b.json) |
| 2026-11-20T11:38:19Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44728767181-1-cad1c759c31b.json) | [JSON](echo/records/2026/44728767181-1-cad1c759c31b.json) |
| 2026-11-19T11:39:18Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44516268660-1-cad1c759c31b.json) | [JSON](echo/records/2026/44516268660-1-cad1c759c31b.json) |
| 2026-11-18T11:41:10Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44296431099-1-cad1c759c31b.json) | [JSON](echo/records/2026/44296431099-1-cad1c759c31b.json) |
| 2026-11-17T11:52:10Z | [`6f2096d70b34`](https://github.com/farbenbuilds/zslay/commit/6f2096d70b34a9e2cebbd8749d08eed5ec6cb693) | [JSON](records/2026/44077306613-1-6f2096d70b34.json) | [JSON](echo/records/2026/44077306613-1-6f2096d70b34.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
