#!/usr/bin/env python3
"""Measure end-to-end WebSocket binary echo over local TCP sockets."""

import argparse
import asyncio
import base64
import hashlib
import json
import math
import os
import statistics
import struct
import time


GUID = b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
MAX_RTT_SAMPLES = 4096


def percentile(values, percent):
    if not values:
        return None
    ordered = sorted(values)
    return ordered[(len(ordered) - 1) * percent // 100]


async def connect(port):
    reader, writer = await asyncio.wait_for(
        asyncio.open_connection("127.0.0.1", port, limit=16384), 5
    )
    try:
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (
            "GET / HTTP/1.1\r\n"
            "Host: 127.0.0.1\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        writer.write(request.encode("ascii"))
        await asyncio.wait_for(writer.drain(), 5)
        response = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 5)
        lines = response.decode("ascii").split("\r\n")
        if not lines[0].startswith("HTTP/1.1 101 "):
            raise ValueError("WebSocket upgrade rejected")
        headers = {}
        for line in lines[1:]:
            if not line:
                continue
            name, separator, value = line.partition(":")
            if not separator or name.lower() in headers:
                raise ValueError("invalid upgrade header")
            headers[name.lower()] = value.strip()
        accept = base64.b64encode(hashlib.sha1(key.encode("ascii") + GUID).digest()).decode("ascii")
        if headers.get("sec-websocket-accept") != accept:
            raise ValueError("invalid Sec-WebSocket-Accept")
        if headers.get("upgrade", "").lower() != "websocket":
            raise ValueError("missing WebSocket upgrade header")
        if "upgrade" not in [token.strip().lower() for token in headers.get("connection", "").split(",")]:
            raise ValueError("missing Connection upgrade token")
        return reader, writer
    except BaseException:
        writer.close()
        await writer.wait_closed()
        raise


def masked_frame(payload):
    size = len(payload)
    header = bytes((0x82, 0x80 | size)) if size < 126 else (
        bytes((0x82, 0xFE)) + struct.pack("!H", size)
        if size <= 65535 else bytes((0x82, 0xFF)) + struct.pack("!Q", size)
    )
    mask = os.urandom(4)
    return header + mask + bytes(value ^ mask[index & 3] for index, value in enumerate(payload))


async def read_echo(reader, payload):
    head = await reader.readexactly(2)
    if head[0] != 0x82 or head[1] & 0x80:
        raise ValueError("expected unmasked, final binary echo frame")
    size = head[1] & 0x7F
    if size == 126:
        size = struct.unpack("!H", await reader.readexactly(2))[0]
    elif size == 127:
        size = struct.unpack("!Q", await reader.readexactly(8))[0]
    if size != len(payload):
        raise ValueError("echo length differs from request")
    if await reader.readexactly(size) != payload:
        raise ValueError("echo payload differs from request")


async def sample(port, connections, payload, duration, keep_rtt):
    successes = 0
    errors = 0
    rtts = []
    opened = []
    try:
        for _ in range(connections):
            opened.append(await connect(port))
    except BaseException:
        for _, writer in opened:
            writer.close()
        await asyncio.gather(*(writer.wait_closed() for _, writer in opened), return_exceptions=True)
        raise

    deadline = time.perf_counter() + duration
    started = time.perf_counter()

    async def worker(index, reader, writer):
        nonlocal successes, errors
        body = bytes((index + offset) & 0xFF for offset in range(len(payload)))
        while time.perf_counter() < deadline:
            try:
                before = time.perf_counter_ns()
                writer.write(masked_frame(body))
                await asyncio.wait_for(writer.drain(), 5)
                await asyncio.wait_for(read_echo(reader, body), 5)
                rtt = time.perf_counter_ns() - before
                successes += 1
                if keep_rtt:
                    if len(rtts) < MAX_RTT_SAMPLES:
                        rtts.append(rtt)
                    else:
                        rtts[(successes - 1) % MAX_RTT_SAMPLES] = rtt
            except (OSError, ValueError, asyncio.TimeoutError, asyncio.IncompleteReadError):
                errors += 1
                break

    try:
        await asyncio.gather(*(worker(index, *pair) for index, pair in enumerate(opened)))
    finally:
        for _, writer in opened:
            writer.close()
        await asyncio.gather(*(writer.wait_closed() for _, writer in opened), return_exceptions=True)
    elapsed = time.perf_counter() - started
    return {
        "duration_seconds": elapsed,
        "operations": successes,
        "errors": errors,
        "ops_per_sec": successes / elapsed,
        "rtt_ns": {f"p{p}": percentile(rtts, p) for p in (50, 95, 99)},
    }


async def run(port, connections, payload_size, duration, warmup):
    payload = bytes(payload_size)
    warmup_result = await sample(port, connections, payload, warmup, False)
    if warmup_result["errors"] or not warmup_result["operations"]:
        raise ValueError("failed or empty warmup")
    samples = [await sample(port, connections, payload, duration, True) for _ in range(3)]
    rtt_summary = {}
    for percent in (50, 95, 99):
        key = f"p{percent}"
        values = [item["rtt_ns"][key] for item in samples if item["rtt_ns"][key] is not None]
        rtt_summary[key] = statistics.median(values) if values else None
    return {
        "schema_version": 1,
        "benchmark": "zslay-echo",
        "connections": connections,
        "payload_bytes": payload_size,
        "duration_seconds": duration,
        "warmup_seconds": warmup,
        "repetitions": 3,
        "samples": samples,
        "ops_per_sec": statistics.median(item["ops_per_sec"] for item in samples),
        "errors": sum(item["errors"] for item in samples),
        "rtt_ns": rtt_summary,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--connections", type=int, default=32)
    parser.add_argument("--payload-size", type=int, default=1024)
    parser.add_argument("--duration", type=float, default=5.0)
    parser.add_argument("--warmup", type=float, default=1.0)
    parser.add_argument("--output", required=True)
    parser.add_argument("--case", action="append", metavar="CONNECTIONS:BYTES")
    args = parser.parse_args()
    if not 0 < args.port < 65536 or not 0 < args.connections <= 128:
        parser.error("port or connections out of range")
    if (not 0 < args.payload_size <= 4096 or not math.isfinite(args.duration) or args.duration <= 0
            or not math.isfinite(args.warmup) or args.warmup <= 0):
        parser.error("payload size and durations must be positive and bounded")
    cases = [(args.connections, args.payload_size)]
    if args.case:
        try:
            cases = [tuple(map(int, value.split(":"))) for value in args.case]
        except ValueError:
            parser.error("each case must be CONNECTIONS:BYTES")
        if any(len(case) != 2 or not 0 < case[0] <= 128 or not 0 < case[1] <= 4096 for case in cases):
            parser.error("case connections or payload size out of range")
        if len(set(cases)) != len(cases):
            parser.error("duplicate case")
    try:
        results = [asyncio.run(run(args.port, n, size, args.duration, args.warmup)) for n, size in cases]
    except (OSError, ValueError, asyncio.TimeoutError) as error:
        parser.exit(1, f"echo benchmark: {error}\n")
    result = {
        "schema_version": 1,
        "benchmark": "zslay-echo",
        "duration_seconds": args.duration,
        "warmup_seconds": args.warmup,
        "repetitions": 3,
        "cases": [
            {"name": f"echo_{item['connections']}c_{item['payload_bytes']}b", **item}
            for item in results
        ],
    }
    with open(args.output, "w", encoding="utf-8") as output:
        json.dump(result, output, indent=2, allow_nan=False)
        output.write("\n")
    if any(item["errors"] or any(not sample["operations"] for sample in item["samples"])
           for item in results):
        parser.exit(1, "echo benchmark: failed or empty echo sample\n")


if __name__ == "__main__":
    main()
