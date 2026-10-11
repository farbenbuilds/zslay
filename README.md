# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-10-11T02:31:25Z](https://github.com/farbenbuilds/zslay/actions/runs/38105320444) from [`bb2a0c7abc01`](https://github.com/farbenbuilds/zslay/commit/bb2a0c7abc01274578af60a9e5b0f5c344d4754a); [workload contract](./contracts/20960835f1a7788ab7a1558a69e92cac523142ca6100a1d17db30a2aa46bba2f.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 0.67 | 1,485,199,982 |
| `header_decode_masked` | 8 | 0.88 | 1,133,761,139 |
| `payload_mask_1024b` | 1,024 | 14.86 | 67,312,009 |
| `conn_rx_state_128b` | 136 | 8.04 | 124,329,862 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-10-11T02:31:25Z](https://github.com/farbenbuilds/zslay/actions/runs/38105320444) from [`bb2a0c7abc01`](https://github.com/farbenbuilds/zslay/commit/bb2a0c7abc01274578af60a9e5b0f5c344d4754a); [workload contract](echo/contracts/c51656c0b06436bedd35082abe451e817c9a0999fd3a869c2098e5411c4d81e0.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 17,209 | 52.95 | 63.77 | 75.65 |
| 1 | 1,024 | 11,107 | 84.01 | 94.58 | 114.63 |
| 64 | 128 | 28,004 | 2,198.65 | 2,324.36 | 2,331.80 |
| 64 | 1,024 | 14,015 | 4,403.12 | 4,559.94 | 5,166.46 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-10-11T02:31:25Z | [`bb2a0c7abc01`](https://github.com/farbenbuilds/zslay/commit/bb2a0c7abc01274578af60a9e5b0f5c344d4754a) | [JSON](records/2026/38105320444-1-bb2a0c7abc01.json) | [JSON](echo/records/2026/38105320444-1-bb2a0c7abc01.json) |
| 2026-10-11T02:28:32Z | [`bb2a0c7abc01`](https://github.com/farbenbuilds/zslay/commit/bb2a0c7abc01274578af60a9e5b0f5c344d4754a) | [JSON](records/2026/38105163229-1-bb2a0c7abc01.json) | [JSON](echo/records/2026/38105163229-1-bb2a0c7abc01.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
