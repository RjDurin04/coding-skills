#!/usr/bin/env python3
"""Hermetic offline tests for run-routing-model-evaluations.py."""

from __future__ import annotations

import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker


ROOT = Path(__file__).resolve().parent.parent
RUNNER = ROOT / "tests" / "run-routing-model-evaluations.py"
CANARY_NAME = "ROUTING_MODEL_TEST_SECRET"
ANSWER_CASE_ID = "answer-engineering-explanation"
ANSWER_REQUEST = (
    "Explain the difference between a retry and an idempotency guarantee "
    "without changing any project files."
)
ANSWER_RATIONALE = (
    "This is a read-only engineering explanation with no additional routing "
    "signal or durable side effect."
)
ANSWER_DECISION = {
    "mode": "answer",
    "signals": ["durable_task"],
    "risk": "trivial",
    "confirmation": "none",
    "lead_skill": None,
    "supporting_skills": [],
}
CANONICAL_ROUTING_THRESHOLD_TARGETS = [
    "scoring.pass_score",
    "scoring.penalties.wrong_mode",
    "scoring.penalties.missing_signal",
    "scoring.penalties.unnecessary_signal",
    "scoring.penalties.risk_underroute_per_level",
    "scoring.penalties.risk_overroute_per_level",
    "scoring.penalties.confirmation_underroute_per_level",
    "scoring.penalties.confirmation_overroute_per_level",
    "scoring.penalties.wrong_lead_skill",
    "scoring.penalties.missing_supporting_skill",
    "scoring.penalties.unnecessary_supporting_skill",
    "scoring.penalties.critical_underroute",
    "manifest.routing_evaluations.minimum_cases",
    "coverage_requirements.maximum_cases",
    "coverage_requirements.minimum_cases_per_signal",
    "coverage_requirements.minimum_cases_per_mode",
    "coverage_requirements.minimum_minimal_route_cases",
]


def load_runner_module() -> Any:
    spec = importlib.util.spec_from_file_location(
        "routing_model_runner_under_test",
        RUNNER,
    )
    if spec is None or spec.loader is None:
        raise AssertionError("could not load routing model runner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


FAKE_ADAPTER_SOURCE = r"""
import json
import os
import pathlib
import subprocess
import sys
import time

mode = sys.argv[1]
capture_path = pathlib.Path(sys.argv[2])
if mode == "no-read":
    time.sleep(30)
    raise SystemExit(9)
payload = json.load(sys.stdin)
with capture_path.open("a", encoding="utf-8") as capture:
    capture.write(json.dumps({
        "payload": payload,
        "secret_seen": "ROUTING_MODEL_TEST_SECRET" in os.environ,
        "supervisor_argv_seen": (
            "ROUTING_MODEL_INTERNAL_ADAPTER_ARGV" in os.environ
        ),
    }, sort_keys=True) + "\n")

decision = {
    "mode": "answer",
    "signals": ["durable_task"],
    "risk": "trivial",
    "confirmation": "none",
    "lead_skill": None,
    "supporting_skills": [],
}

if mode == "pass":
    print(json.dumps(decision))
elif mode == "mutate":
    pathlib.Path("unexpected.txt").write_text("mutation", encoding="utf-8")
    print(json.dumps(decision))
elif mode == "invalid":
    decision["unexpected_oracle_guess"] = True
    print(json.dumps(decision))
elif mode == "sleep":
    time.sleep(2)
    print(json.dumps(decision))
elif mode == "oversize":
    sys.stdout.write("x" * 8192)
elif mode.startswith("spawn-child-"):
    marker_path = capture_path.with_suffix(".survived")
    child_source = (
        "import pathlib,sys,time;"
        "time.sleep(5);"
        "pathlib.Path(sys.argv[1]).write_text('survived',encoding='utf-8')"
    )
    child = subprocess.Popen([
        sys.executable,
        "-c",
        child_source,
        str(marker_path),
    ])

    with capture_path.open("a", encoding="utf-8") as capture:
        capture.write(json.dumps({"child_pid": child.pid}) + "\n")
    if mode == "spawn-child-normal":
        print(json.dumps(decision))
    elif mode == "spawn-child-timeout":
        time.sleep(30)
    elif mode == "spawn-child-output":
        sys.stdout.write("x" * 8192)
        sys.stdout.flush()
        time.sleep(30)
    else:
        raise SystemExit(8)
else:
    raise SystemExit(7)
"""


class RoutingModelRunnerTests(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        self.temp_directory = tempfile.TemporaryDirectory(
            prefix="routing-model-runner-test-"
        )
        self.temp = Path(self.temp_directory.name)
        self.fake_adapter = self.temp / "fake_adapter.py"
        self.fake_adapter.write_text(
            FAKE_ADAPTER_SOURCE,
            encoding="utf-8",
            newline="\n",
        )
        self.fixture_root = self.temp / "fixture-root"
        self.fixture_root.mkdir()
        fixture_schemas = self.fixture_root / "schemas"
        fixture_schemas.mkdir()
        for schema_name in (
            "routing-evaluations.schema.json",
            "routing-model-adapter.schema.json",
        ):
            shutil.copyfile(
                ROOT / "schemas" / schema_name,
                fixture_schemas / schema_name,
            )
        manifest = {
            "pack_version": "test-1.0.0",
            "risk_order": ["trivial", "standard", "structural", "critical"],
            "confirmation_order": [
                "none",
                "explicit_authorization",
                "fresh_confirmation",
            ],
            "task_modes": {
                "answer": {
                    "required_signals": ["durable_task"],
                }
            },
            "routing_signals": {
                "durable_task": {
                    "minimum_risk": "trivial",
                    "confirmation": "none",
                    "lead_skill": None,
                    "supporting_skills": [],
                }
            },
            "risk_overlays": [],
            "skills": [],
            "routing_evaluations": {
                "minimum_cases": 1,
            },
        }
        (self.fixture_root / "governance-manifest.json").write_text(
            json.dumps(manifest, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        self.public_catalog = {
            "$schema": "../schemas/routing-evaluations.schema.json",
            "schema_version": 2,
            "oracle": {
                "kind": "human_semantic",
                "owner": "offline-test",
                "basis": (
                    "A hermetic authored oracle for exercising the routing "
                    "model runner without external dependencies."
                ),
                "reviewed_on": "2026-07-26",
                "pack_version": "test-1.0.0",
            },
            "threshold_policies": [
                {
                    "id": "offline-routing-score-policy",
                    "classification": "derived",
                    "status": "candidate",
                    "owner": "offline-test",
                    "basis": (
                        "Test-only values mirror the canonical scorer shape "
                        "without making a production assurance claim."
                    ),
                    "evidence_refs": [],
                    "reviewed_on": "2026-07-26",
                    "review_by": "2099-01-01",
                    "targets": list(CANONICAL_ROUTING_THRESHOLD_TARGETS),
                }
            ],
            "coverage_requirements": {
                "maximum_cases": 10,
                "minimum_cases_per_signal": 1,
                "minimum_cases_per_mode": 1,
                "minimum_minimal_route_cases": 1,
            },
            "scoring": {
                "pass_score": 85,
                "penalties": {
                    "wrong_mode": 25,
                    "missing_signal": 20,
                    "unnecessary_signal": 5,
                    "risk_underroute_per_level": 25,
                    "risk_overroute_per_level": 7,
                    "confirmation_underroute_per_level": 35,
                    "confirmation_overroute_per_level": 10,
                    "wrong_lead_skill": 20,
                    "missing_supporting_skill": 8,
                    "unnecessary_supporting_skill": 4,
                    "critical_underroute": 100,
                },
            },
            "cases": [
                {
                    "id": ANSWER_CASE_ID,
                    "request": ANSWER_REQUEST,
                    "rationale": ANSWER_RATIONALE,
                    "expected": ANSWER_DECISION,
                }
            ],
        }
        self.public_catalog_path = self.temp / "public-routing.json"
        self.public_catalog_path.write_text(
            json.dumps(self.public_catalog, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )

    def tearDown(self) -> None:
        self.temp_directory.cleanup()

    def write_adapter(
        self,
        adapter_id: str,
        mode: str,
        capture_path: Path,
        *,
        instruction_binding: str = "test-repository-rules",
        argv_override: list[str] | None = None,
    ) -> Path:
        adapter = {
            "$schema": "../schemas/routing-model-adapter.schema.json",
            "schema_version": 1,
            "id": adapter_id,
            "argv": (
                argv_override
                if argv_override is not None
                else [
                    sys.executable,
                    str(self.fake_adapter),
                    mode,
                    str(capture_path),
                ]
            ),
            "environment_allowlist": [],
            "model": {
                "provider": "offline-test",
                "name": adapter_id,
                "version": "1",
                "agent_surface": "fake-stdio",
            },
            "instruction_binding": instruction_binding,
        }
        path = self.temp / f"{adapter_id}.adapter.json"
        path.write_text(
            json.dumps(adapter, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        return path

    def run_runner(
        self,
        *,
        catalog_flag: str,
        catalog_path: Path,
        adapters: list[Path],
        output_path: Path,
        trials: int = 1,
        timeout_seconds: float = 10,
        max_request_bytes: int = 65536,
        max_output_bytes: int = 4096,
        max_invocations: int = 100,
        variants: Path | None = None,
        cases: list[str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        command = [
            sys.executable,
            str(RUNNER),
            "--root",
            str(self.fixture_root),
            catalog_flag,
            str(catalog_path),
        ]
        for adapter in adapters:
            command.extend(["--adapter", str(adapter)])
        if variants is not None:
            command.extend(["--variants", str(variants)])
        for case_id in cases or []:
            command.extend(["--case", case_id])
        command.extend(
            [
                "--trials",
                str(trials),
                "--timeout-seconds",
                str(timeout_seconds),
                "--max-request-bytes",
                str(max_request_bytes),
                "--max-output-bytes",
                str(max_output_bytes),
                "--max-invocations",
                str(max_invocations),
                "--output",
                str(output_path),
            ]
        )
        environment = dict(os.environ)
        environment[CANARY_NAME] = "must-not-reach-adapter"
        return subprocess.run(
            command,
            cwd=ROOT,
            env=environment,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )

    @staticmethod
    def read_report(path: Path) -> dict[str, Any]:
        return json.loads(path.read_text(encoding="utf-8"))

    @staticmethod
    def read_capture(path: Path) -> list[dict[str, Any]]:
        return [
            json.loads(line)
            for line in path.read_text(encoding="utf-8").splitlines()
            if line
        ]

    def assert_report_valid(self, report: dict[str, Any]) -> None:
        errors = self.report_validation_errors(report)
        self.assertEqual(
            errors,
            [],
            "\n".join(
                f"{'/'.join(str(part) for part in error.absolute_path)}: "
                f"{error.message}"
                for error in errors
            ),
        )

    @staticmethod
    def report_validation_errors(report: dict[str, Any]) -> list[Any]:
        schema = json.loads(
            (
                ROOT
                / "schemas"
                / "routing-model-evaluation-report.schema.json"
            ).read_text(encoding="utf-8")
        )
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(
            schema,
            format_checker=FormatChecker(),
        )
        errors = sorted(
            validator.iter_errors(report),
            key=lambda error: tuple(str(part) for part in error.absolute_path),
        )
        return errors

    def test_public_cross_model_trials_send_request_only_and_sanitize_env(
        self,
    ) -> None:
        source_case = self.public_catalog["cases"][0]
        capture_a = self.temp / "capture-a.jsonl"
        capture_b = self.temp / "capture-b.jsonl"
        adapter_a = self.write_adapter("model-a", "pass", capture_a)
        adapter_b = self.write_adapter("model-b", "pass", capture_b)
        report_path = self.temp / "public-report.json"

        result = self.run_runner(
            catalog_flag="--public-catalog",
            catalog_path=self.public_catalog_path,
            adapters=[adapter_a, adapter_b],
            output_path=report_path,
            trials=2,
            cases=[ANSWER_CASE_ID],
        )

        report = self.read_report(report_path)
        self.assert_report_valid(report)
        self.assertEqual(
            result.returncode,
            0,
            result.stderr + result.stdout + json.dumps(report, indent=2),
        )
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["comparison"]["adapter_count"], 2)
        self.assertEqual(report["comparison"]["shared_case_count"], 1)
        self.assertTrue(report["comparison"]["comparable"])
        self.assertTrue(report["comparison"]["all_adapters_pass"])
        self.assertEqual(report["execution"]["selection_scope"], "full")
        self.assertEqual(report["execution"]["selected_case_count"], 1)
        self.assertEqual(report["execution"]["max_request_bytes"], 65536)
        self.assertEqual(report["execution"]["max_invocations"], 100)
        self.assertEqual(report["execution"]["planned_invocations"], 4)
        self.assertEqual(
            report["execution"]["process_containment"],
            (
                "windows_job_plus_observed_descendants"
                if os.name == "nt"
                else "posix_process_group"
            ),
        )
        for adapter_result in report["adapters"]:
            self.assertEqual(adapter_result["summary"]["total_trials"], 2)
            self.assertEqual(adapter_result["summary"]["pass"], 2)
            self.assertEqual(adapter_result["status"], "PASS")

        for capture_path in (capture_a, capture_b):
            captures = self.read_capture(capture_path)
            self.assertEqual(len(captures), 2)
            for capture in captures:
                self.assertEqual(
                    capture["payload"],
                    {"request": source_case["request"]},
                )
                self.assertEqual(set(capture["payload"]), {"request"})
                self.assertFalse(capture["secret_seen"])
                self.assertFalse(capture["supervisor_argv_seen"])

        serialized = report_path.read_text(encoding="utf-8")
        self.assertNotIn(source_case["request"], serialized)
        self.assertNotIn(source_case["rationale"], serialized)
        self.assertNotIn('"expected"', serialized)

    def test_private_catalog_and_authored_variant_redact_identifiers_and_oracle(
        self,
    ) -> None:
        public = self.public_catalog
        source_case = public["cases"][0]
        inline_variant_id = "private-answer-paraphrase"
        inline_variant_request = (
            "Paraphrase the request: explain retries and idempotency without "
            "changing files or external state."
        )
        private_source_case = dict(source_case)
        private_source_case["variants"] = [
            {
                "id": inline_variant_id,
                "request": inline_variant_request,
            }
        ]
        private_catalog = {
            "$schema": public["$schema"],
            "schema_version": 2,
            "oracle": public["oracle"],
            "threshold_policies": public["threshold_policies"],
            "coverage_requirements": public["coverage_requirements"],
            "scoring": public["scoring"],
            "cases": [private_source_case],
        }
        private_catalog_path = self.temp / "private-routing.json"
        private_catalog_path.write_text(
            json.dumps(private_catalog, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        external_variant_id = "private-answer-reordered"
        external_variant_request = (
            "Without making project or external changes, explain idempotency "
            "guarantees and retries in that reordered request."
        )
        variants_path = self.temp / "private-variants.json"
        variants_path.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "variants": [
                        {
                            "id": external_variant_id,
                            "base_case_id": ANSWER_CASE_ID,
                            "request": external_variant_request,
                        }
                    ],
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
            newline="\n",
        )
        capture = self.temp / "private-capture.jsonl"
        adapter = self.write_adapter("private-model", "pass", capture)
        report_path = self.temp / "private-report.json"

        result = self.run_runner(
            catalog_flag="--private-catalog",
            catalog_path=private_catalog_path,
            adapters=[adapter],
            output_path=report_path,
            variants=variants_path,
        )

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        report = self.read_report(report_path)
        self.assert_report_valid(report)
        self.assertEqual(report["catalog"]["visibility"], "private")
        self.assertRegex(
            report["catalog"]["variants_sha256"],
            r"^[a-f0-9]{64}$",
        )
        self.assertEqual(report["catalog"]["base_case_count"], 1)
        self.assertEqual(report["catalog"]["variant_count"], 2)
        cases = report["adapters"][0]["cases"]
        self.assertEqual(len(cases), 3)
        self.assertTrue(
            all(
                re.fullmatch(r"private-[a-f0-9]{64}", case["case_ref"])
                for case in cases
            )
        )
        self.assertIsNotNone(cases[1]["variant_of"])
        self.assertIsNotNone(cases[2]["variant_of"])
        self.assertEqual(cases[1]["variant_of"], cases[0]["case_ref"])
        self.assertEqual(cases[2]["variant_of"], cases[0]["case_ref"])
        for case in cases:
            self.assertIsNone(case["trials"][0]["score"])

        private_schema_mutations = (
            (
                "raw-case-ref",
                lambda candidate: candidate["adapters"][0]["cases"][0].__setitem__(
                    "case_ref",
                    ANSWER_CASE_ID,
                ),
            ),
            (
                "raw-variant-ref",
                lambda candidate: candidate["adapters"][0]["cases"][1].__setitem__(
                    "variant_of",
                    ANSWER_CASE_ID,
                ),
            ),
            (
                "numeric-score",
                lambda candidate: candidate["adapters"][0]["cases"][0][
                    "trials"
                ][0].__setitem__("score", 100),
            ),
        )
        for name, mutate in private_schema_mutations:
            with self.subTest(private_schema=name):
                schema_invalid_private = json.loads(json.dumps(report))
                mutate(schema_invalid_private)
                self.assertTrue(
                    self.report_validation_errors(schema_invalid_private),
                    "private report schema must reject identifiers and scores",
                )

        serialized = report_path.read_text(encoding="utf-8")
        for forbidden in (
            ANSWER_CASE_ID,
            inline_variant_id,
            external_variant_id,
            source_case["request"],
            source_case["rationale"],
            inline_variant_request,
            external_variant_request,
            '"expected"',
        ):
            self.assertNotIn(forbidden, serialized)

        captures = self.read_capture(capture)
        self.assertEqual(
            [entry["payload"]["request"] for entry in captures],
            [
                source_case["request"],
                inline_variant_request,
                external_variant_request,
            ],
        )

        second_capture = self.temp / "private-second-capture.jsonl"
        second_adapter = self.write_adapter(
            "private-model-second",
            "pass",
            second_capture,
        )
        second_report_path = self.temp / "private-second-report.json"
        second_result = self.run_runner(
            catalog_flag="--private-catalog",
            catalog_path=private_catalog_path,
            adapters=[second_adapter],
            output_path=second_report_path,
            variants=variants_path,
        )
        self.assertEqual(
            second_result.returncode,
            0,
            second_result.stderr + second_result.stdout,
        )
        second_report = self.read_report(second_report_path)
        self.assert_report_valid(second_report)
        first_refs = [case["case_ref"] for case in cases]
        second_refs = [
            case["case_ref"]
            for case in second_report["adapters"][0]["cases"]
        ]
        self.assertNotEqual(
            first_refs,
            second_refs,
            "private references must use a fresh per-report HMAC secret",
        )

    def test_partial_selection_never_reports_full_pass(self) -> None:
        catalog = json.loads(json.dumps(self.public_catalog))
        catalog["cases"][0]["variants"] = [
            {
                "id": "answer-engineering-paraphrase",
                "request": (
                    "Explain retries and idempotency in different words "
                    "without changing project files."
                ),
            }
        ]
        catalog_path = self.temp / "partial-routing.json"
        catalog_path.write_text(
            json.dumps(catalog, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )

        scenarios = (
            ("pass", 4, "PARTIAL", "PASS"),
            ("mutate", 1, "FAIL", "FAIL"),
        )
        for mode, expected_exit, expected_report, expected_adapter in scenarios:
            with self.subTest(mode=mode):
                capture = self.temp / f"partial-{mode}-capture.jsonl"
                adapter = self.write_adapter(
                    f"partial-{mode}-model",
                    mode,
                    capture,
                )
                report_path = self.temp / f"partial-{mode}-report.json"
                result = self.run_runner(
                    catalog_flag="--public-catalog",
                    catalog_path=catalog_path,
                    adapters=[adapter],
                    output_path=report_path,
                    cases=[ANSWER_CASE_ID],
                )
                self.assertEqual(
                    result.returncode,
                    expected_exit,
                    result.stderr + result.stdout,
                )
                report = self.read_report(report_path)
                self.assert_report_valid(report)
                self.assertEqual(report["status"], expected_report)
                self.assertEqual(
                    report["adapters"][0]["status"],
                    expected_adapter,
                )
                self.assertEqual(
                    report["execution"]["selection_scope"],
                    "partial",
                )
                self.assertEqual(
                    report["execution"]["selected_case_count"],
                    1,
                )

        invalid_underlying = self.read_report(
            self.temp / "partial-pass-report.json"
        )
        invalid_underlying["adapters"][0]["status"] = "PARTIAL"
        self.assertTrue(
            self.report_validation_errors(invalid_underlying),
            "PARTIAL must be valid only for the top-level status",
        )

    def test_nonreading_adapter_stays_under_shared_deadline(self) -> None:
        catalog = json.loads(json.dumps(self.public_catalog))
        request = (
            "Explain retry and idempotency semantics without changing files. "
            + ("x" * 262_144)
        )
        catalog["cases"][0]["request"] = request
        catalog_path = self.temp / "nonreading-routing.json"
        catalog_path.write_text(
            json.dumps(catalog, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        envelope_size = len(
            (
                json.dumps({"request": request}, ensure_ascii=False) + "\n"
            ).encode("utf-8")
        )
        capture = self.temp / "nonreading-capture.jsonl"
        adapter = self.write_adapter(
            "nonreading-model",
            "no-read",
            capture,
        )
        report_path = self.temp / "nonreading-report.json"

        started = time.monotonic()
        result = self.run_runner(
            catalog_flag="--public-catalog",
            catalog_path=catalog_path,
            adapters=[adapter],
            output_path=report_path,
            timeout_seconds=0.25,
            max_request_bytes=envelope_size,
        )
        elapsed = time.monotonic() - started

        self.assertEqual(
            result.returncode,
            2,
            result.stderr + result.stdout,
        )
        self.assertLess(elapsed, 15)
        report = self.read_report(report_path)
        self.assert_report_valid(report)
        self.assertEqual(report["status"], "ERROR")
        trial = report["adapters"][0]["cases"][0]["trials"][0]
        self.assertEqual(trial["status"], "ERROR")
        self.assertIn("timeout", trial["failure_classes"])
        self.assertTrue(trial["process"]["timed_out"])
        self.assertFalse(capture.exists())

    def test_delayed_supervisor_return_cannot_pass_after_deadline(self) -> None:
        runner = load_runner_module()

        class RecordingInput(io.BytesIO):
            def __init__(self) -> None:
                super().__init__()
                self.write_calls = 0

            def write(self, content: bytes) -> int:
                self.write_calls += 1
                return super().write(content)

        class FakeHandle:
            def Close(self) -> None:
                return None

        class AlreadyExitedProcess:
            def __init__(self) -> None:
                self.stdin = RecordingInput()
                self.stdout = io.BytesIO(
                    (json.dumps(ANSWER_DECISION) + "\n").encode("utf-8")
                )
                self.stderr = io.BytesIO()
                self.returncode = 0
                self.pid = 999_999
                self._handle = FakeHandle()

            def poll(self) -> int:
                return 0

            def wait(self, timeout: float | None = None) -> int:
                del timeout
                return 0

        fake_process = AlreadyExitedProcess()

        def delayed_start(
            adapter: dict[str, Any],
            process_arguments: dict[str, Any],
        ) -> tuple[Any, None]:
            del adapter, process_arguments
            time.sleep(0.03)
            return fake_process, None

        original_start = runner._start_adapter_supervisor
        original_terminate = runner.terminate_process_tree
        runner._start_adapter_supervisor = delayed_start
        runner.terminate_process_tree = lambda process, job: None
        try:
            (
                process_record,
                _stdout,
                _stderr,
                _workspace,
                process_error,
            ) = runner.execute_adapter(
                {
                    "argv": ["unused"],
                    "environment_allowlist": [],
                },
                runner.serialize_request_envelope(ANSWER_REQUEST, 65536),
                0.001,
                4096,
            )
        finally:
            runner.terminate_process_tree = original_terminate
            runner._start_adapter_supervisor = original_start

        self.assertTrue(process_record["timed_out"])
        self.assertEqual(process_error, "timeout")
        self.assertEqual(fake_process.stdin.write_calls, 0)

    def test_request_case_and_invocation_limits_prevent_launch(self) -> None:
        capture = self.temp / "limits-capture.jsonl"
        adapter = self.write_adapter("limits-model", "pass", capture)

        request_report = self.temp / "request-limit-report.json"
        request_result = self.run_runner(
            catalog_flag="--public-catalog",
            catalog_path=self.public_catalog_path,
            adapters=[adapter],
            output_path=request_report,
            max_request_bytes=1,
        )
        self.assertEqual(request_result.returncode, 2)
        self.assertIn("--max-request-bytes", request_result.stderr)
        self.assertFalse(request_report.exists())
        self.assertFalse(capture.exists())

        nonpositive_report = self.temp / "nonpositive-invocation-report.json"
        nonpositive_result = self.run_runner(
            catalog_flag="--public-catalog",
            catalog_path=self.public_catalog_path,
            adapters=[adapter],
            output_path=nonpositive_report,
            max_invocations=0,
        )
        self.assertEqual(nonpositive_result.returncode, 2)
        self.assertIn("--max-invocations must be at least 1", nonpositive_result.stderr)
        self.assertFalse(nonpositive_report.exists())
        self.assertFalse(capture.exists())

        second_capture = self.temp / "limits-second-capture.jsonl"
        second_adapter = self.write_adapter(
            "limits-second-model",
            "pass",
            second_capture,
        )
        fanout_report = self.temp / "fanout-limit-report.json"
        fanout_result = self.run_runner(
            catalog_flag="--public-catalog",
            catalog_path=self.public_catalog_path,
            adapters=[adapter, second_adapter],
            output_path=fanout_report,
            trials=2,
            max_invocations=3,
        )
        self.assertEqual(fanout_result.returncode, 2)
        self.assertIn("planned 4", fanout_result.stderr)
        self.assertFalse(fanout_report.exists())
        self.assertFalse(capture.exists())
        self.assertFalse(second_capture.exists())

        bounded_catalog = json.loads(json.dumps(self.public_catalog))
        bounded_catalog["coverage_requirements"]["maximum_cases"] = 1
        bounded_catalog_path = self.temp / "bounded-routing.json"
        bounded_catalog_path.write_text(
            json.dumps(bounded_catalog, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        variants_path = self.temp / "over-limit-variants.json"
        variants_path.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "variants": [
                        {
                            "id": "answer-over-limit-variant",
                            "base_case_id": ANSWER_CASE_ID,
                            "request": (
                                "Explain idempotency and retry behavior "
                                "without changing any files."
                            ),
                        }
                    ],
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
            newline="\n",
        )
        case_report = self.temp / "case-limit-report.json"
        case_result = self.run_runner(
            catalog_flag="--public-catalog",
            catalog_path=bounded_catalog_path,
            adapters=[adapter],
            variants=variants_path,
            output_path=case_report,
            cases=[ANSWER_CASE_ID],
        )
        self.assertEqual(case_result.returncode, 2)
        self.assertIn("total runnable case count", case_result.stderr)
        self.assertFalse(case_report.exists())
        self.assertFalse(capture.exists())

    def test_unrounded_score_controls_threshold_comparison(self) -> None:
        runner = load_runner_module()
        manifest = json.loads(
            (
                self.fixture_root / "governance-manifest.json"
            ).read_text(encoding="utf-8")
        )
        catalog = json.loads(json.dumps(self.public_catalog))
        catalog["scoring"]["penalties"]["unnecessary_signal"] = 15.001
        actual = json.loads(json.dumps(ANSWER_DECISION))
        actual["signals"].append("extra-signal")

        score, status, failures, critical = runner.score_decision(
            actual,
            ANSWER_DECISION,
            catalog,
            manifest,
        )

        self.assertEqual(score, 85.0)
        self.assertEqual(status, "FAIL")
        self.assertIn("unnecessary_signal", failures)
        self.assertFalse(critical)

        ulp_catalog = json.loads(json.dumps(self.public_catalog))
        ulp_catalog["scoring"]["penalties"][
            "missing_signal"
        ] = 15.000000000000002
        ulp_manifest = json.loads(json.dumps(manifest))
        ulp_manifest["routing_signals"]["extra-signal"] = {
            "minimum_risk": "trivial",
            "confirmation": "none",
            "lead_skill": None,
            "supporting_skills": [],
        }
        ulp_expected = json.loads(json.dumps(ANSWER_DECISION))
        ulp_expected["signals"].append("extra-signal")
        (
            ulp_score,
            ulp_status,
            ulp_failures,
            ulp_critical,
        ) = runner.score_decision(
            ANSWER_DECISION,
            ulp_expected,
            ulp_catalog,
            ulp_manifest,
        )
        self.assertEqual(ulp_score, 85.0)
        self.assertEqual(ulp_status, "FAIL")
        self.assertIn("missing_signal", ulp_failures)
        self.assertFalse(ulp_critical)

    def test_declared_schemas_precede_hand_validation(self) -> None:
        capture = self.temp / "schema-first-capture.jsonl"
        adapter = self.write_adapter(
            "schema-first-model",
            "pass",
            capture,
        )
        mutations = (
            (
                "short-oracle-basis",
                lambda catalog: catalog["oracle"].__setitem__(
                    "basis",
                    "too short",
                ),
            ),
            (
                "empty-inline-variants",
                lambda catalog: catalog["cases"][0].__setitem__(
                    "variants",
                    [],
                ),
            ),
        )
        for name, mutate in mutations:
            with self.subTest(name=name):
                catalog = json.loads(json.dumps(self.public_catalog))
                mutate(catalog)
                catalog_path = self.temp / f"{name}.json"
                catalog_path.write_text(
                    json.dumps(catalog, indent=2) + "\n",
                    encoding="utf-8",
                    newline="\n",
                )
                report_path = self.temp / f"{name}-report.json"
                result = self.run_runner(
                    catalog_flag="--public-catalog",
                    catalog_path=catalog_path,
                    adapters=[adapter],
                    output_path=report_path,
                )
                self.assertEqual(result.returncode, 2)
                self.assertIn(
                    "does not satisfy its Draft 2020-12 schema",
                    result.stderr,
                )
                self.assertFalse(report_path.exists())
        self.assertFalse(capture.exists())

    def test_fail_invalid_timeout_and_output_limit_status_contracts(self) -> None:
        scenarios = (
            ("mutate", 10, 4096, 1, "FAIL", "workspace_mutation"),
            ("invalid", 10, 4096, 2, "INVALID", "decision_shape"),
            ("sleep", 0.1, 4096, 2, "ERROR", "timeout"),
            ("oversize", 10, 128, 2, "ERROR", "output_limit"),
        )
        for mode, timeout, max_output, expected_exit, expected_status, finding in scenarios:
            with self.subTest(mode=mode):
                capture = self.temp / f"{mode}-capture.jsonl"
                adapter = self.write_adapter(f"{mode}-model", mode, capture)
                report_path = self.temp / f"{mode}-report.json"
                result = self.run_runner(
                    catalog_flag="--public-catalog",
                    catalog_path=self.public_catalog_path,
                    adapters=[adapter],
                    output_path=report_path,
                    timeout_seconds=timeout,
                    max_output_bytes=max_output,
                    cases=[ANSWER_CASE_ID],
                )
                diagnostic_report = (
                    self.read_report(report_path) if report_path.exists() else {}
                )
                self.assertEqual(
                    result.returncode,
                    expected_exit,
                    result.stderr
                    + result.stdout
                    + json.dumps(diagnostic_report, indent=2),
                )
                report = diagnostic_report
                self.assertEqual(report["status"], expected_status)
                trial = report["adapters"][0]["cases"][0]["trials"][0]
                self.assertEqual(trial["status"], expected_status)
                self.assertIn(finding, trial["failure_classes"])
                if mode == "mutate":
                    self.assertTrue(trial["workspace"]["mutated"])
                    self.assertGreater(trial["workspace"]["changed_count"], 0)
                if mode == "oversize":
                    self.assertTrue(trial["process"]["output_limited"])

    def test_adapter_config_rejects_secret_bearing_argv(self) -> None:
        secret_arguments = (
            ("api-key", ["--api-key", "not-a-real-secret"]),
            ("generic-key", ["--key", "not-a-real-secret"]),
            (
                "aws-assignment",
                ["AWS_SECRET_ACCESS_KEY=not-a-real-secret"],
            ),
            (
                "jwt-family",
                [
                    "eyJabcdefghijk.eyJabcdefghijkl."
                    "abcdefghijklmnop"
                ],
            ),
            ("token-family", ["xoxb-123456789012-abcdefghijkl"]),
        )
        for name, arguments in secret_arguments:
            with self.subTest(name=name):
                capture = self.temp / f"{name}-secret-capture.jsonl"
                adapter = self.write_adapter(
                    f"unsafe-{name}-model",
                    "pass",
                    capture,
                    argv_override=[
                        sys.executable,
                        str(self.fake_adapter),
                        *arguments,
                    ],
                )
                report_path = self.temp / f"{name}-unsafe-report.json"

                result = self.run_runner(
                    catalog_flag="--public-catalog",
                    catalog_path=self.public_catalog_path,
                    adapters=[adapter],
                    output_path=report_path,
                    cases=[ANSWER_CASE_ID],
                )

                self.assertEqual(result.returncode, 2)
                self.assertIn(
                    "best-effort secret scan flagged adapter argv",
                    result.stderr,
                )
                self.assertFalse(report_path.exists())
                self.assertFalse(capture.exists())

    def test_catalog_requires_v2_and_exact_schema(self) -> None:
        capture = self.temp / "catalog-contract-capture.jsonl"
        adapter = self.write_adapter(
            "catalog-contract-model",
            "pass",
            capture,
        )
        invalid_catalogs = []
        version_one = json.loads(json.dumps(self.public_catalog))
        version_one["schema_version"] = 1
        invalid_catalogs.append(
            (
                "version-one",
                version_one,
                "does not satisfy its Draft 2020-12 schema",
            )
        )
        wrong_schema = json.loads(json.dumps(self.public_catalog))
        wrong_schema["$schema"] = "../schemas/not-routing-v2.schema.json"
        invalid_catalogs.append(
            (
                "wrong-schema",
                wrong_schema,
                "does not satisfy its Draft 2020-12 schema",
            )
        )

        for name, catalog, expected_error in invalid_catalogs:
            with self.subTest(name=name):
                catalog_path = self.temp / f"{name}.json"
                catalog_path.write_text(
                    json.dumps(catalog, indent=2) + "\n",
                    encoding="utf-8",
                    newline="\n",
                )
                report_path = self.temp / f"{name}-report.json"
                result = self.run_runner(
                    catalog_flag="--private-catalog",
                    catalog_path=catalog_path,
                    adapters=[adapter],
                    output_path=report_path,
                )
                self.assertEqual(result.returncode, 2)
                self.assertIn(expected_error, result.stderr)
                self.assertFalse(report_path.exists())
        self.assertFalse(capture.exists())

    def test_private_catalog_rejects_invalid_threshold_metadata(self) -> None:
        capture = self.temp / "invalid-threshold-capture.jsonl"
        adapter = self.write_adapter(
            "invalid-threshold-model",
            "pass",
            capture,
        )

        def missing_target(catalog: dict[str, Any]) -> None:
            catalog["threshold_policies"][0]["targets"].remove(
                "coverage_requirements.minimum_minimal_route_cases"
            )

        def duplicate_owner(catalog: dict[str, Any]) -> None:
            duplicate = json.loads(
                json.dumps(catalog["threshold_policies"][0])
            )
            duplicate["id"] = "duplicate-threshold-owner"
            duplicate["classification"] = "safety_policy"
            duplicate["targets"] = ["scoring.pass_score"]
            catalog["threshold_policies"].append(duplicate)

        def nonderived_critical(catalog: dict[str, Any]) -> None:
            catalog["threshold_policies"][0]["classification"] = "safety_policy"

        def empirical_without_evidence(catalog: dict[str, Any]) -> None:
            catalog["threshold_policies"][0]["classification"] = "empirical"
            catalog["threshold_policies"][0]["evidence_refs"] = []

        def expired_review(catalog: dict[str, Any]) -> None:
            catalog["threshold_policies"][0]["review_by"] = "2020-01-01"

        def invalid_status(catalog: dict[str, Any]) -> None:
            catalog["threshold_policies"][0]["status"] = "approved"

        scenarios = (
            ("missing-target", missing_target, "exactly cover"),
            ("duplicate-owner", duplicate_owner, "exactly one owner"),
            (
                "nonderived-critical",
                nonderived_critical,
                "critical_underroute target",
            ),
            (
                "empirical-without-evidence",
                empirical_without_evidence,
                "does not satisfy its Draft 2020-12 schema",
            ),
            ("expired-review", expired_review, "review_by is expired"),
            (
                "invalid-status",
                invalid_status,
                "does not satisfy its Draft 2020-12 schema",
            ),
        )
        for name, mutate, expected_error in scenarios:
            with self.subTest(name=name):
                catalog = json.loads(json.dumps(self.public_catalog))
                mutate(catalog)
                catalog_path = self.temp / f"{name}-private-routing.json"
                catalog_path.write_text(
                    json.dumps(catalog, indent=2) + "\n",
                    encoding="utf-8",
                    newline="\n",
                )
                report_path = self.temp / f"{name}-private-report.json"
                result = self.run_runner(
                    catalog_flag="--private-catalog",
                    catalog_path=catalog_path,
                    adapters=[adapter],
                    output_path=report_path,
                )
                self.assertEqual(result.returncode, 2)
                self.assertIn(expected_error, result.stderr)
                self.assertFalse(report_path.exists())
        self.assertFalse(capture.exists())

    def test_private_catalog_rejects_undercoverage_before_selection(self) -> None:
        manifest_path = self.fixture_root / "governance-manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["routing_evaluations"]["minimum_cases"] = 2
        manifest_path.write_text(
            json.dumps(manifest, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )

        private_catalog_path = self.temp / "undercovered-private-routing.json"
        private_catalog_path.write_text(
            json.dumps(self.public_catalog, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        capture = self.temp / "undercovered-private-capture.jsonl"
        adapter = self.write_adapter(
            "undercovered-private-model",
            "pass",
            capture,
        )
        report_path = self.temp / "undercovered-private-report.json"

        result = self.run_runner(
            catalog_flag="--private-catalog",
            catalog_path=private_catalog_path,
            adapters=[adapter],
            output_path=report_path,
            cases=[ANSWER_CASE_ID],
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("base-case count must be between", result.stderr)
        self.assertFalse(report_path.exists())
        self.assertFalse(capture.exists())

    def test_adapter_descendants_are_terminated_on_all_completion_paths(
        self,
    ) -> None:
        scenarios = (
            ("spawn-child-normal", 10, 4096, 0, "PASS"),
            ("spawn-child-timeout", 4.5, 4096, 2, "ERROR"),
            ("spawn-child-output", 10, 128, 2, "ERROR"),
        )
        markers: list[Path] = []
        child_pids: list[int] = []

        for mode, timeout, max_output, expected_exit, expected_status in scenarios:
            with self.subTest(mode=mode):
                capture = self.temp / f"{mode}.jsonl"
                marker = capture.with_suffix(".survived")
                markers.append(marker)
                adapter = self.write_adapter(f"{mode}-model", mode, capture)
                report_path = self.temp / f"{mode}-report.json"
                result = self.run_runner(
                    catalog_flag="--public-catalog",
                    catalog_path=self.public_catalog_path,
                    adapters=[adapter],
                    output_path=report_path,
                    timeout_seconds=timeout,
                    max_output_bytes=max_output,
                    cases=[ANSWER_CASE_ID],
                )
                self.assertEqual(
                    result.returncode,
                    expected_exit,
                    result.stderr + result.stdout,
                )
                self.assertTrue(
                    report_path.exists(),
                    result.stderr
                    + result.stdout
                    + (
                        "\nCAPTURE:\n" + capture.read_text(encoding="utf-8")
                        if capture.exists()
                        else "\nCAPTURE: missing"
                    ),
                )
                report = self.read_report(report_path)
                self.assert_report_valid(report)
                self.assertEqual(report["status"], expected_status)
                captures = self.read_capture(capture)
                pid_records = [
                    entry for entry in captures if "child_pid" in entry
                ]
                self.assertEqual(
                    len(pid_records),
                    1,
                    "the adapter must prove that it spawned one descendant",
                )
                child_pids.append(int(pid_records[0]["child_pid"]))

        self.assertEqual(len(child_pids), len(scenarios))
        time.sleep(6)
        self.assertEqual(
            [marker for marker in markers if marker.exists()],
            [],
            "an adapter descendant survived runner process-tree cleanup",
        )

    @unittest.skipUnless(os.name == "nt", "Windows process contract")
    def test_windows_breakaway_access_denied_retries_with_fresh_job(self) -> None:
        runner = load_runner_module()

        class AccessDenied(OSError):
            winerror = 5

        class FakeProcess:
            pass

        class FakeJob:
            instances: list["FakeJob"] = []

            def __init__(self) -> None:
                self.assigned: list[Any] = []
                self.terminated = False
                self.instances.append(self)

            def assign_and_resume(self, process: Any) -> None:
                self.assigned.append(process)

            def terminate(self) -> None:
                self.terminated = True

        creation_flags: list[int] = []

        def fake_popen(argv: list[str], **arguments: Any) -> Any:
            del argv
            creation_flags.append(int(arguments["creationflags"]))
            if len(creation_flags) == 1:
                raise AccessDenied("breakaway denied")
            return FakeProcess()

        process, job = runner._start_windows_adapter_process(
            ["fake-adapter"],
            {},
            popen_factory=fake_popen,
            job_factory=FakeJob,
        )

        self.assertIsInstance(process, FakeProcess)
        self.assertIs(job, FakeJob.instances[1])
        self.assertEqual(len(FakeJob.instances), 2)
        self.assertTrue(FakeJob.instances[0].terminated)
        self.assertFalse(FakeJob.instances[1].terminated)
        self.assertNotEqual(
            creation_flags[0] & runner._CREATE_BREAKAWAY_FROM_JOB,
            0,
        )
        self.assertEqual(
            creation_flags[1] & runner._CREATE_BREAKAWAY_FROM_JOB,
            0,
        )
        self.assertNotEqual(
            creation_flags[1] & runner._CREATE_SUSPENDED,
            0,
        )

    @unittest.skipUnless(os.name == "nt", "Windows process contract")
    def test_windows_cleanup_uses_retained_identity_handles(self) -> None:
        runner = load_runner_module()

        class FakeKernel:
            def __init__(self) -> None:
                self.terminated: list[str] = []
                self.closed: list[str] = []
                self.open_calls = 0

            def OpenProcess(self, *arguments: Any) -> Any:
                del arguments
                self.open_calls += 1
                raise AssertionError("cleanup must not reopen historical PIDs")

            def WaitForSingleObject(
                self,
                process_handle: str,
                timeout_ms: int,
            ) -> int:
                del timeout_ms
                if (
                    process_handle == "expired-handle"
                    or process_handle in self.terminated
                ):
                    return runner._WAIT_OBJECT_0
                return runner._WAIT_TIMEOUT

            def TerminateProcess(
                self,
                process_handle: str,
                exit_code: int,
            ) -> bool:
                del exit_code
                self.terminated.append(process_handle)
                return process_handle != "pending-handle"

            def CloseHandle(self, process_handle: str) -> bool:
                self.closed.append(process_handle)
                return True

        job = runner._WindowsProcessJob.__new__(runner._WindowsProcessJob)
        job.root_pid = 100
        job.root_process_handle = "root-handle"
        job.descendant_handles = {
            201: ["expired-handle"],
            202: ["live-handle", "pending-handle"],
        }
        job.handle = None
        job.completion_port = None
        job.observe_descendants = lambda: None
        fake_kernel = FakeKernel()
        original_kernel = runner._kernel32
        runner._kernel32 = fake_kernel
        try:
            job.terminate_retained_descendants(time.monotonic() + 1)
            job.close_descendant_handles()
        finally:
            runner._kernel32 = original_kernel

        self.assertEqual(fake_kernel.open_calls, 0)
        self.assertEqual(
            fake_kernel.terminated,
            ["live-handle", "pending-handle"],
        )
        self.assertCountEqual(
            fake_kernel.closed,
            ["expired-handle", "live-handle", "pending-handle"],
        )
        self.assertEqual(job.descendant_handles, {})

    @unittest.skipUnless(os.name == "nt", "Windows process contract")
    def test_windows_expired_pid_does_not_seed_snapshot_ancestry(self) -> None:
        runner = load_runner_module()

        class FakeKernel:
            def __init__(self) -> None:
                self.open_calls = 0

            def WaitForSingleObject(
                self,
                process_handle: str,
                timeout_ms: int,
            ) -> int:
                del timeout_ms
                if process_handle == "expired-handle":
                    return runner._WAIT_OBJECT_0
                return runner._WAIT_TIMEOUT

            def OpenProcess(self, *arguments: Any) -> Any:
                del arguments
                self.open_calls += 1
                raise AssertionError(
                    "an expired retained PID must not seed new ancestry"
                )

        job = runner._WindowsProcessJob.__new__(runner._WindowsProcessJob)
        job.root_pid = 100
        job.root_process_handle = "live-root-handle"
        job.descendant_handles = {201: ["expired-handle"]}
        job.handle = None
        job.completion_port = None
        fake_kernel = FakeKernel()
        original_kernel = runner._kernel32
        original_parents = runner._windows_process_parents
        runner._kernel32 = fake_kernel
        runner._windows_process_parents = lambda: {202: 201}
        try:
            job.observe_descendants()
        finally:
            runner._windows_process_parents = original_parents
            runner._kernel32 = original_kernel

        self.assertEqual(fake_kernel.open_calls, 0)
        self.assertEqual(job.descendant_handles, {201: ["expired-handle"]})

    @unittest.skipUnless(os.name == "nt", "Windows process contract")
    def test_windows_access_denied_in_retain_descendant_is_ignored(self) -> None:
        runner = load_runner_module()

        class FakeKernel:
            def __init__(self) -> None:
                self.open_calls = 0

            def WaitForSingleObject(
                self,
                process_handle: str,
                timeout_ms: int,
            ) -> int:
                del timeout_ms, process_handle
                return runner._WAIT_TIMEOUT

            def OpenProcess(self, *arguments: Any) -> Any:
                del arguments
                self.open_calls += 1
                runner.ctypes.set_last_error(runner._ERROR_ACCESS_DENIED)
                return None

        job = runner._WindowsProcessJob.__new__(runner._WindowsProcessJob)
        job.root_pid = 100
        job.root_process_handle = "live-root-handle"
        job.descendant_handles = {}
        job.handle = None
        job.completion_port = None
        fake_kernel = FakeKernel()
        original_kernel = runner._kernel32
        original_parents = runner._windows_process_parents
        runner._kernel32 = fake_kernel
        runner._windows_process_parents = lambda: {202: 100}
        try:
            job.observe_descendants()
        finally:
            runner._windows_process_parents = original_parents
            runner._kernel32 = original_kernel

        self.assertEqual(fake_kernel.open_calls, 1)
        self.assertEqual(job.descendant_handles, {})

    def test_new_json_contracts_and_template_are_strict_json(self) -> None:
        adapter_schema = json.loads(
            (ROOT / "schemas" / "routing-model-adapter.schema.json").read_text(
                encoding="utf-8"
            )
        )
        report_schema = json.loads(
            (
                ROOT
                / "schemas"
                / "routing-model-evaluation-report.schema.json"
            ).read_text(encoding="utf-8")
        )
        template = json.loads(
            (ROOT / "templates" / "ROUTING-MODEL-ADAPTER.json").read_text(
                encoding="utf-8"
            )
        )

        self.assertFalse(adapter_schema["additionalProperties"])
        self.assertFalse(report_schema["additionalProperties"])
        self.assertEqual(
            set(template),
            set(adapter_schema["required"]),
        )
        self.assertEqual(template["environment_allowlist"], [])
        self.assertNotIn("api_key", template)
        self.assertNotIn("credentials", template)


if __name__ == "__main__":
    unittest.main(verbosity=2)
