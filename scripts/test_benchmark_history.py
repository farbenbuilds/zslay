import argparse
import hashlib
import json
import pathlib
import tempfile
import unittest

import benchmark_history


class BenchmarkHistoryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.contract = self.root / "CONTRACT.md"
        self.contract.write_text("fixed benchmark workload\n")
        self.record = self.root / "record.json"
        self.data = {
            "schema_version": 1,
            "benchmark": "zslay-core",
            "warmup_operations": 10,
            "iterations_per_sample": 100,
            "repetitions": 2,
            "cases": [{
                "name": "mask_payload",
                "bytes_per_op": 64,
                "ns_per_op": 2.5,
                "ops_per_sec": 400_000_000.0,
                "samples_ns_per_op": [2.0, 3.0],
                "sample_durations_ns": [200, 300],
            }],
            "record_id": "123-1-abcdefabcdef",
            "recorded_at": "2026-10-10T12:00:00Z",
            "source_sha": "abcdefabcdef" + "0" * 28,
            "contract_sha256": hashlib.sha256(self.contract.read_bytes()).hexdigest(),
        }
        self.record.write_text(json.dumps(self.data))
        self.history = self.root / "history"
        self.args = argparse.Namespace(record=self.record, history=self.history, contract=self.contract)

    def test_publish_is_idempotent_and_conflicts_fail(self):
        benchmark_history.publish(self.args)
        record_path = self.history / "records/2026/123-1-abcdefabcdef.json"
        contract_path = self.history / "contracts" / f"{self.data['contract_sha256']}.md"
        self.assertEqual(json.loads(record_path.read_text()), self.data)
        self.assertEqual(json.loads((self.history / "latest.json").read_text()), self.data)
        self.assertEqual(len(json.loads((self.history / "index.json").read_text())["records"]), 1)
        (self.history / "latest.json").unlink()
        (self.history / "index.json").unlink()
        contract_path.unlink()
        benchmark_history.publish(self.args)
        self.assertEqual(json.loads((self.history / "latest.json").read_text()), self.data)
        self.assertEqual(len(json.loads((self.history / "index.json").read_text())["records"]), 1)
        self.assertEqual(contract_path.read_bytes(), self.contract.read_bytes())
        self.data["cases"][0]["ns_per_op"] = 3.5
        self.record.write_text(json.dumps(self.data))
        with self.assertRaisesRegex(ValueError, "conflicting record"):
            benchmark_history.publish(self.args)

    def test_wrong_contract_does_not_write_history(self):
        self.contract.write_text("changed workload\n")
        with self.assertRaisesRegex(ValueError, "checksum does not match"):
            benchmark_history.publish(self.args)
        self.assertFalse(self.history.exists())

    def test_incompatible_base_is_reported_as_skipped(self):
        candidate = self.root / "candidate.json"
        baseline = self.root / "baseline.json"
        comparison = self.root / "comparison.json"
        candidate.write_text(json.dumps(self.data))
        baseline.write_text(json.dumps({**self.data, "iterations_per_sample": 200}))
        benchmark_history.compare(argparse.Namespace(candidate=candidate, baseline=baseline, output=comparison))
        result = json.loads(comparison.read_text())
        self.assertEqual(result["status"], "skipped")
        self.assertEqual(result["reason"], "benchmark workloads differ")

    def test_invalid_candidate_fails_comparison(self):
        candidate = self.root / "candidate.json"
        baseline = self.root / "baseline.json"
        comparison = self.root / "comparison.json"
        candidate.write_text("not JSON")
        baseline.write_text(json.dumps(self.data))
        with self.assertRaises(ValueError):
            benchmark_history.compare(argparse.Namespace(candidate=candidate, baseline=baseline, output=comparison))
        self.assertFalse(comparison.exists())

    def test_invalid_sample_count_fails(self):
        self.data["cases"][0]["samples_ns_per_op"] = [2.0]
        self.record.write_text(json.dumps(self.data))
        with self.assertRaisesRegex(ValueError, "invalid samples"):
            benchmark_history.load_result(self.record)

    def test_echo_history_is_isolated_and_validated(self):
        sample = {
            "duration_seconds": 5.01,
            "operations": 100,
            "errors": 0,
            "ops_per_sec": 19.96,
            "rtt_ns": {"p50": 100, "p95": 200, "p99": 300},
        }
        echo = {
            **self.data,
            "benchmark": "zslay-echo",
            "duration_seconds": 5,
            "warmup_seconds": 1,
            "repetitions": 3,
            "cases": [
                {
                    "schema_version": 1,
                    "benchmark": "zslay-echo",
                    "name": f"echo_{connections}c_{size}b",
                    "connections": connections,
                    "payload_bytes": size,
                    "duration_seconds": 5,
                    "warmup_seconds": 1,
                    "repetitions": 3,
                    "samples": [sample] * 3,
                    "ops_per_sec": 19.96,
                    "errors": 0,
                    "rtt_ns": sample["rtt_ns"],
                }
                for connections in (1, 64) for size in (128, 1024)
            ],
        }
        self.record.write_text(json.dumps(echo))
        benchmark_history.publish_echo(self.args)
        self.assertEqual(json.loads((self.history / "echo/latest.json").read_text()), echo)
        self.assertFalse((self.history / "latest.json").exists())
        comparison = self.root / "echo-comparison.json"
        benchmark_history.compare_echo(argparse.Namespace(
            candidate=self.record, baseline=self.record, output=comparison,
        ))
        compared = json.loads(comparison.read_text())
        self.assertEqual(compared["status"], "compared")
        self.assertTrue(all(case["candidate_to_baseline_speedup"] == 1 for case in compared["cases"]))
        echo["cases"][0]["samples"][0]["errors"] = 1
        self.record.write_text(json.dumps(echo))
        with self.assertRaisesRegex(ValueError, "echo sample has errors"):
            benchmark_history.publish_echo(self.args)

    def test_readme_shows_latest_results_and_regenerates_without_new_run(self):
        self.data["github"] = {"repository": "farbenbuilds/zslay", "run_id": "123"}
        self.record.write_text(json.dumps(self.data))
        benchmark_history.publish(self.args)
        sample = {
            "duration_seconds": 5.01, "operations": 100, "errors": 0, "ops_per_sec": 19.96,
            "rtt_ns": {"p50": 1000, "p95": 2000, "p99": 3000},
        }
        echo = {
            **self.data, "benchmark": "zslay-echo", "duration_seconds": 5, "warmup_seconds": 1,
            "repetitions": 3,
            "cases": [{
                "schema_version": 1, "benchmark": "zslay-echo",
                "name": f"echo_{connections}c_{size}b", "connections": connections,
                "payload_bytes": size, "duration_seconds": 5, "warmup_seconds": 1,
                "repetitions": 3, "samples": [sample] * 3, "ops_per_sec": 19.96,
                "errors": 0, "rtt_ns": sample["rtt_ns"],
            } for connections in (1, 64) for size in (128, 1024)],
        }
        self.record.write_text(json.dumps(echo))
        benchmark_history.publish_echo(self.args)
        args = argparse.Namespace(history=self.history)
        benchmark_history.render_readme(args)
        readme = (self.history / "README.md").read_text()
        self.assertIn("| `mask_payload` | 64 | 2.50 | 400,000,000 |", readme)
        self.assertIn("| 64 | 1,024 | 20 | 1.00 | 2.00 | 3.00 |", readme)
        self.assertIn("[JSON](records/2026/123-1-abcdefabcdef.json)", readme)
        self.assertIn("[JSON](echo/records/2026/123-1-abcdefabcdef.json)", readme)
        self.assertIn("[Latest core JSON](latest.json)", readme)
        self.assertIn("[Latest echo JSON](echo/latest.json)", readme)
        self.assertIn("https://github.com/farbenbuilds/zslay/actions/runs/123", readme)
        benchmark_history.render_readme(args)
        self.assertEqual((self.history / "README.md").read_text(), readme)
        core_path = self.history / "latest.json"
        core = json.loads(core_path.read_text())
        core["github"]["repository"] = "far ben/zslay"
        core_path.write_text(json.dumps(core))
        with self.assertRaisesRegex(ValueError, "invalid GitHub repository"):
            benchmark_history.render_readme(args)
        self.assertEqual((self.history / "README.md").read_text(), readme)


if __name__ == "__main__":
    unittest.main()
