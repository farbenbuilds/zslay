#!/usr/bin/env python3
"""Validate benchmark output and maintain the benchmark-data branch."""

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import pathlib
import platform
import re


def load_result(path):
    result = json.loads(pathlib.Path(path).read_text())
    if result.get("schema_version") != 1 or result.get("benchmark") != "zslay-core":
        raise ValueError("unsupported benchmark schema")
    for key in ("warmup_operations", "iterations_per_sample", "repetitions"):
        if type(result.get(key)) is not int or result[key] <= 0:
            raise ValueError(f"invalid {key}")
    cases = result.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValueError("benchmark has no cases")
    names = set()
    for case in cases:
        name = case.get("name")
        if not isinstance(name, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", name) or name in names:
            raise ValueError("invalid or duplicate case name")
        names.add(name)
        if type(case.get("bytes_per_op")) is not int or case["bytes_per_op"] <= 0:
            raise ValueError(f"invalid bytes_per_op for {name}")
        for key in ("ns_per_op", "ops_per_sec"):
            value = case.get(key)
            if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
                raise ValueError(f"invalid {key} for {name}")
        samples = case.get("samples_ns_per_op")
        if not isinstance(samples, list) or len(samples) != result["repetitions"]:
            raise ValueError(f"invalid samples for {name}")
        if any(type(value) not in (int, float) or not math.isfinite(value) or value <= 0 for value in samples):
            raise ValueError(f"invalid sample value for {name}")
        durations = case.get("sample_durations_ns")
        if not isinstance(durations, list) or len(durations) != result["repetitions"]:
            raise ValueError(f"invalid sample durations for {name}")
        if any(type(value) is not int or value <= 0 for value in durations):
            raise ValueError(f"invalid sample duration for {name}")
    return result


def validate_echo_case(case):
    if not isinstance(case, dict):
        raise ValueError("invalid echo case")
    if (case.get("schema_version"), case.get("benchmark")) != (1, "zslay-echo"):
        raise ValueError("unsupported echo benchmark schema")
    if case.get("connections") not in (1, 64) or case.get("payload_bytes") not in (128, 1024):
        raise ValueError("unknown echo workload")
    if case.get("name") != f'echo_{case["connections"]}c_{case["payload_bytes"]}b':
        raise ValueError("invalid echo case name")
    if case.get("duration_seconds") != 5 or case.get("warmup_seconds") != 1 or case.get("repetitions") != 3:
        raise ValueError("echo workload differs from contract")
    if type(case.get("errors")) is not int or case["errors"] != 0:
        raise ValueError("echo case has errors")
    samples = case.get("samples")
    if not isinstance(samples, list) or len(samples) != 3:
        raise ValueError("invalid echo samples")
    for sample in samples:
        if not isinstance(sample, dict) or type(sample.get("operations")) is not int or sample["operations"] <= 0:
            raise ValueError("invalid echo operations")
        if type(sample.get("errors")) is not int or sample["errors"] != 0:
            raise ValueError("echo sample has errors")
        for key in ("duration_seconds", "ops_per_sec"):
            value = sample.get(key)
            if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
                raise ValueError(f"invalid echo {key}")
        validate_rtt(sample.get("rtt_ns"))
    value = case.get("ops_per_sec")
    if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
        raise ValueError("invalid echo aggregate rate")
    validate_rtt(case.get("rtt_ns"))


def validate_rtt(rtt):
    if not isinstance(rtt, dict):
        raise ValueError("invalid echo RTT")
    values = [rtt.get(key) for key in ("p50", "p95", "p99")]
    if any(type(value) not in (int, float) or not math.isfinite(value) or value <= 0 for value in values):
        raise ValueError("invalid echo RTT percentile")
    if values != sorted(values):
        raise ValueError("echo RTT percentiles out of order")


def validate_echo_record(result):
    if not isinstance(result, dict) or result.get("schema_version") != 1 or result.get("benchmark") != "zslay-echo":
        raise ValueError("unsupported echo record schema")
    if result.get("duration_seconds") != 5 or result.get("warmup_seconds") != 1 or result.get("repetitions") != 3:
        raise ValueError("echo workload differs from contract")
    cases = result.get("cases")
    if not isinstance(cases, list) or len(cases) != 4:
        raise ValueError("echo record requires four cases")
    for case in cases:
        validate_echo_case(case)
    workloads = {(case["connections"], case["payload_bytes"]) for case in cases}
    if workloads != {(1, 128), (1, 1024), (64, 128), (64, 1024)}:
        raise ValueError("echo record has duplicate or missing workloads")
    return result


def load_echo_record(path):
    return validate_echo_record(json.loads(pathlib.Path(path).read_text()))


def write_json(path, value):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n")


def make_record(args, loader=load_result):
    result = loader(args.input)
    contract_sha256 = hashlib.sha256(pathlib.Path(args.contract).read_bytes()).hexdigest()
    source_sha = os.environ["SOURCE_SHA"]
    run_id = os.environ["GITHUB_RUN_ID"]
    attempt = os.environ["GITHUB_RUN_ATTEMPT"]
    if not re.fullmatch(r"[0-9a-f]{40}", source_sha) or not run_id.isdigit() or not attempt.isdigit():
        raise ValueError("invalid GitHub run metadata")
    timestamp = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    record = {
        **result,
        "record_id": f"{run_id}-{attempt}-{source_sha[:12]}",
        "recorded_at": timestamp,
        "source_sha": source_sha,
        "contract_sha256": contract_sha256,
        "github": {
            "repository": os.environ["GITHUB_REPOSITORY"],
            "event": os.environ["GITHUB_EVENT_NAME"],
            "run_id": run_id,
            "run_attempt": attempt,
        },
        "runner": {
            "image": os.environ.get("ImageOS", "unknown"),
            "cpu": pathlib.Path("/proc/cpuinfo").read_text().split("model name\t: ")[-1].splitlines()[0]
            if pathlib.Path("/proc/cpuinfo").exists() else platform.processor(),
            "kernel": platform.release(),
            "machine": platform.machine(),
        },
        "toolchain": {
            "zig": os.environ["ZIG_VERSION"],
            "flake_lock_sha256": hashlib.sha256(pathlib.Path("flake.lock").read_bytes()).hexdigest(),
            "optimize": "ReleaseFast",
        },
    }
    write_json(args.output, record)


def make_echo_record(args):
    make_record(args, load_echo_record)


def compare(args):
    candidate = load_result(args.candidate)
    def skip(reason):
        write_json(args.output, {
            "schema_version": 1,
            "benchmark": "zslay-core",
            "status": "skipped",
            "reason": reason,
        })

    try:
        baseline = load_result(args.baseline)
    except ValueError:
        skip("baseline result is not compatible with the current schema")
        return
    parameters = ("warmup_operations", "iterations_per_sample", "repetitions")
    if any(candidate[key] != baseline[key] for key in parameters):
        skip("benchmark workloads differ")
        return
    base_cases = {case["name"]: case for case in baseline["cases"]}
    if set(base_cases) != {case["name"] for case in candidate["cases"]}:
        skip("benchmark case sets differ")
        return
    comparisons = []
    for case in candidate["cases"]:
        base = base_cases[case["name"]]
        if case["bytes_per_op"] != base["bytes_per_op"]:
            skip("benchmark case payloads differ")
            return
        comparisons.append({
            "name": case["name"],
            "candidate_ns_per_op": case["ns_per_op"],
            "baseline_ns_per_op": base["ns_per_op"],
            "candidate_to_baseline_speedup": base["ns_per_op"] / case["ns_per_op"],
        })
    write_json(args.output, {
        "schema_version": 1,
        "benchmark": "zslay-core",
        "status": "compared",
        "cases": comparisons,
    })


def compare_echo(args):
    candidate = load_echo_record(args.candidate)

    def skip(reason):
        write_json(args.output, {
            "schema_version": 1,
            "benchmark": "zslay-echo",
            "status": "skipped",
            "reason": reason,
        })

    try:
        baseline = load_echo_record(args.baseline)
    except (KeyError, ValueError, TypeError):
        skip("baseline result is not compatible with the current schema")
        return
    parameters = ("duration_seconds", "warmup_seconds", "repetitions")
    if any(candidate[key] != baseline[key] for key in parameters):
        skip("echo benchmark workloads differ")
        return
    base_cases = {case["name"]: case for case in baseline["cases"]}
    comparisons = []
    for case in candidate["cases"]:
        base = base_cases[case["name"]]
        comparisons.append({
            "name": case["name"],
            "candidate_ops_per_sec": case["ops_per_sec"],
            "baseline_ops_per_sec": base["ops_per_sec"],
            "candidate_to_baseline_speedup": case["ops_per_sec"] / base["ops_per_sec"],
        })
    write_json(args.output, {
        "schema_version": 1,
        "benchmark": "zslay-echo",
        "status": "compared",
        "cases": comparisons,
    })


def publish(args, loader=load_result, namespace=""):
    record = json.loads(pathlib.Path(args.record).read_text())
    loader(args.record)
    record_id = record["record_id"]
    recorded_at = record["recorded_at"]
    if not re.fullmatch(r"[0-9]+-[0-9]+-[0-9a-f]{12}", record_id):
        raise ValueError("invalid record ID")
    year = dt.datetime.fromisoformat(recorded_at.replace("Z", "+00:00")).year
    root = pathlib.Path(args.history) / namespace
    relative_path = pathlib.Path("records") / str(year) / f"{record_id}.json"
    output = root / relative_path
    contract_bytes = pathlib.Path(args.contract).read_bytes()
    digest = hashlib.sha256(contract_bytes).hexdigest()
    if digest != record["contract_sha256"]:
        raise ValueError("record contract checksum does not match source")
    destination = root / "contracts" / f"{digest}.md"
    if destination.exists() and destination.read_bytes() != contract_bytes:
        raise ValueError("conflicting benchmark contract")
    if output.exists():
        if json.loads(output.read_text()) != record:
            raise ValueError(f"conflicting record: {relative_path}")
    entries = []
    for path in (root / "records").glob("*/*.json"):
        item = json.loads(path.read_text())
        entries.append({
            "record_id": item["record_id"],
            "record_path": path.relative_to(root).as_posix(),
            "recorded_at": item["recorded_at"],
            "source_sha": item["source_sha"],
        })
    if not output.exists():
        entries.append({
            "record_id": record_id,
            "record_path": relative_path.as_posix(),
            "recorded_at": recorded_at,
            "source_sha": record["source_sha"],
        })
    entries.sort(key=lambda item: (item["recorded_at"], item["record_id"]), reverse=True)
    latest_path = root / entries[0]["record_path"]
    latest = record if latest_path == output else json.loads(latest_path.read_text())
    if not output.exists():
        write_json(output, record)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        destination.write_bytes(contract_bytes)
    write_json(root / "index.json", {"schema_version": 1, "benchmark": record["benchmark"], "records": entries})
    write_json(root / "latest.json", latest)


def publish_echo(args):
    publish(args, load_echo_record, "echo")


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    record = commands.add_parser("record")
    record.add_argument("--input", required=True)
    record.add_argument("--output", required=True)
    record.add_argument("--contract", required=True)
    record.set_defaults(func=make_record)
    echo_record = commands.add_parser("record-echo")
    echo_record.add_argument("--input", required=True)
    echo_record.add_argument("--output", required=True)
    echo_record.add_argument("--contract", required=True)
    echo_record.set_defaults(func=make_echo_record)
    comparison = commands.add_parser("compare")
    comparison.add_argument("--candidate", required=True)
    comparison.add_argument("--baseline", required=True)
    comparison.add_argument("--output", required=True)
    comparison.set_defaults(func=compare)
    echo_comparison = commands.add_parser("compare-echo")
    echo_comparison.add_argument("--candidate", required=True)
    echo_comparison.add_argument("--baseline", required=True)
    echo_comparison.add_argument("--output", required=True)
    echo_comparison.set_defaults(func=compare_echo)
    history = commands.add_parser("publish")
    history.add_argument("--record", required=True)
    history.add_argument("--history", required=True)
    history.add_argument("--contract", required=True)
    history.set_defaults(func=publish)
    echo_history = commands.add_parser("publish-echo")
    echo_history.add_argument("--record", required=True)
    echo_history.add_argument("--history", required=True)
    echo_history.add_argument("--contract", required=True)
    echo_history.set_defaults(func=publish_echo)
    args = parser.parse_args()
    try:
        args.func(args)
    except (KeyError, ValueError, OSError) as error:
        parser.exit(1, f"benchmark history: {error}\n")


if __name__ == "__main__":
    main()
