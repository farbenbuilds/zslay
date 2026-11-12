# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-12T11:06:12Z](https://github.com/farbenbuilds/zslay/actions/runs/43205595086) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.15 | 867,265,080 |
| `header_decode_masked` | 8 | 2.16 | 463,344,793 |
| `payload_mask_1024b` | 1,024 | 22.33 | 44,776,026 |
| `conn_rx_state_128b` | 136 | 17.86 | 56,000,072 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-12T11:06:12Z](https://github.com/farbenbuilds/zslay/actions/runs/43205595086) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 9,176 | 93.79 | 143.60 | 163.05 |
| 1 | 1,024 | 6,003 | 156.73 | 215.03 | 234.99 |
| 64 | 128 | 15,865 | 4,010.83 | 4,108.77 | 4,171.46 |
| 64 | 1,024 | 7,357 | 8,158.17 | 11,227.95 | 11,310.79 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-12T11:06:12Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43205595086-1-0043f942169a.json) | [JSON](echo/records/2026/43205595086-1-0043f942169a.json) |
| 2026-11-11T10:57:23Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43007492270-1-0043f942169a.json) | [JSON](echo/records/2026/43007492270-1-0043f942169a.json) |
| 2026-11-10T11:11:35Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42804965813-1-0043f942169a.json) | [JSON](echo/records/2026/42804965813-1-0043f942169a.json) |
| 2026-11-09T11:31:16Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42609202431-1-0043f942169a.json) | [JSON](echo/records/2026/42609202431-1-0043f942169a.json) |
| 2026-11-08T10:20:24Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/42470788038-1-0043f942169a.json) | [JSON](echo/records/2026/42470788038-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
