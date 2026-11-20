# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-20T11:38:19Z](https://github.com/farbenbuilds/zslay/actions/runs/44728767181) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.92 | 1,086,377,907 |
| `header_decode_masked` | 8 | 6.35 | 157,502,886 |
| `payload_mask_1024b` | 1,024 | 19.79 | 50,530,648 |
| `conn_rx_state_128b` | 136 | 19.61 | 50,994,677 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-20T11:38:19Z](https://github.com/farbenbuilds/zslay/actions/runs/44728767181) from [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 12,999 | 72.82 | 96.96 | 110.78 |
| 1 | 1,024 | 7,898 | 122.95 | 153.35 | 164.70 |
| 64 | 128 | 23,362 | 2,733.97 | 2,791.31 | 3,188.24 |
| 64 | 1,024 | 10,419 | 5,915.69 | 6,094.20 | 7,313.39 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-20T11:38:19Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44728767181-1-cad1c759c31b.json) | [JSON](echo/records/2026/44728767181-1-cad1c759c31b.json) |
| 2026-11-19T11:39:18Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44516268660-1-cad1c759c31b.json) | [JSON](echo/records/2026/44516268660-1-cad1c759c31b.json) |
| 2026-11-18T11:41:10Z | [`cad1c759c31b`](https://github.com/farbenbuilds/zslay/commit/cad1c759c31b2fa7c80392ccfadab90a3a1ed762) | [JSON](records/2026/44296431099-1-cad1c759c31b.json) | [JSON](echo/records/2026/44296431099-1-cad1c759c31b.json) |
| 2026-11-17T11:52:10Z | [`6f2096d70b34`](https://github.com/farbenbuilds/zslay/commit/6f2096d70b34a9e2cebbd8749d08eed5ec6cb693) | [JSON](records/2026/44077306613-1-6f2096d70b34.json) | [JSON](echo/records/2026/44077306613-1-6f2096d70b34.json) |
| 2026-11-16T11:15:17Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43855656731-1-0043f942169a.json) | [JSON](echo/records/2026/43855656731-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
