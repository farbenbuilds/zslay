# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-15T10:53:30Z](https://github.com/farbenbuilds/zslay/actions/runs/43705947124) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.04 | 960,947,109 |
| `header_decode_masked` | 8 | 2.17 | 461,695,438 |
| `payload_mask_1024b` | 1,024 | 22.37 | 44,701,728 |
| `conn_rx_state_128b` | 136 | 17.84 | 56,054,849 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-15T10:53:30Z](https://github.com/farbenbuilds/zslay/actions/runs/43705947124) from [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 9,284 | 91.98 | 132.02 | 146.38 |
| 1 | 1,024 | 6,211 | 150.01 | 199.90 | 222.76 |
| 64 | 128 | 15,976 | 3,958.77 | 4,082.37 | 4,177.41 |
| 64 | 1,024 | 7,549 | 8,054.99 | 10,870.79 | 10,917.61 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-15T10:53:30Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43705947124-1-0043f942169a.json) | [JSON](echo/records/2026/43705947124-1-0043f942169a.json) |
| 2026-11-14T10:26:38Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43584947598-1-0043f942169a.json) | [JSON](echo/records/2026/43584947598-1-0043f942169a.json) |
| 2026-11-13T10:59:39Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43412925664-1-0043f942169a.json) | [JSON](echo/records/2026/43412925664-1-0043f942169a.json) |
| 2026-11-12T11:06:12Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43205595086-1-0043f942169a.json) | [JSON](echo/records/2026/43205595086-1-0043f942169a.json) |
| 2026-11-11T10:57:23Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43007492270-1-0043f942169a.json) | [JSON](echo/records/2026/43007492270-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
