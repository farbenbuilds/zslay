# zslay benchmark results

Results from the scheduled and manual benchmark workflow on `main`. Each table shows the latest published run for its suite. GitHub-hosted runner hardware and load vary, so compare runs with their workload and environment metadata.

## Core framing operations

Latest: [2026-11-17T11:52:10Z](https://github.com/farbenbuilds/zslay/actions/runs/44077306613) from [`6f2096d70b34`](https://github.com/farbenbuilds/zslay/commit/6f2096d70b34a9e2cebbd8749d08eed5ec6cb693); [workload contract](./contracts/0654a1fc00a723f950b001981660993485abcd727d18efdc85e39cb68604ccbc.md)

| Case | Bytes per operation | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| `header_encode_masked` | 8 | 1.23 | 810,865,599 |
| `header_decode_masked` | 8 | 9.11 | 109,783,102 |
| `payload_mask_1024b` | 1,024 | 23.27 | 42,971,718 |
| `conn_rx_state_128b` | 136 | 25.11 | 39,823,058 |

Core operations run in process; they do not include socket I/O.

## WebSocket echo round trips

Latest: [2026-11-17T11:52:10Z](https://github.com/farbenbuilds/zslay/actions/runs/44077306613) from [`6f2096d70b34`](https://github.com/farbenbuilds/zslay/commit/6f2096d70b34a9e2cebbd8749d08eed5ec6cb693); [workload contract](echo/contracts/0d9d35373fdc3a4a064ed27b72538ac2b3c4c90b3bfefc3a3015991821d0326e.md)

| Connections | Payload (bytes) | round trips/s | p50 RTT (us) | p95 RTT (us) | p99 RTT (us) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 128 | 9,234 | 93.22 | 145.42 | 164.70 |
| 1 | 1,024 | 6,034 | 153.48 | 210.04 | 227.10 |
| 64 | 128 | 15,591 | 4,040.17 | 5,324.75 | 5,394.66 |
| 64 | 1,024 | 7,560 | 7,981.30 | 8,113.61 | 8,223.44 |

Each echo operation is one validated masked request and unmasked response over loopback TCP.
Core ops/s and echo round trips/s measure different work and are not directly comparable.

## Recent runs

| Recorded (UTC) | Source | Core record | Echo record |
| --- | --- | --- | --- |
| 2026-11-17T11:52:10Z | [`6f2096d70b34`](https://github.com/farbenbuilds/zslay/commit/6f2096d70b34a9e2cebbd8749d08eed5ec6cb693) | [JSON](records/2026/44077306613-1-6f2096d70b34.json) | [JSON](echo/records/2026/44077306613-1-6f2096d70b34.json) |
| 2026-11-16T11:15:17Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43855656731-1-0043f942169a.json) | [JSON](echo/records/2026/43855656731-1-0043f942169a.json) |
| 2026-11-15T10:53:30Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43705947124-1-0043f942169a.json) | [JSON](echo/records/2026/43705947124-1-0043f942169a.json) |
| 2026-11-14T10:26:38Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43584947598-1-0043f942169a.json) | [JSON](echo/records/2026/43584947598-1-0043f942169a.json) |
| 2026-11-13T10:59:39Z | [`0043f942169a`](https://github.com/farbenbuilds/zslay/commit/0043f942169a863fda397d293c88eeb33f0837de) | [JSON](records/2026/43412925664-1-0043f942169a.json) | [JSON](echo/records/2026/43412925664-1-0043f942169a.json) |

[Latest core JSON](latest.json) · [Latest echo JSON](echo/latest.json) · [Complete core history](index.json) · [Complete echo history](echo/index.json) · [Benchmark workflow](https://github.com/farbenbuilds/zslay/actions/workflows/benchmark.yml)
