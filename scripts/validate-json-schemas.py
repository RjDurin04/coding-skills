#!/usr/bin/env python3
"""Meta-validate governance schemas and execute them against canonical artifacts."""

from __future__ import annotations

import argparse
import copy
import json
import sys
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
from typing import Any

EXPECTED_JSONSCHEMA_VERSION = "4.26.0"


def reject_nonstandard_constant(token: str) -> None:
    raise ValueError(f"non-standard JSON numeric constant is forbidden: {token}")


def load_json(path: Path) -> Any:
    return json.loads(
        path.read_text(encoding="utf-8"),
        parse_constant=reject_nonstandard_constant,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
    )
    args = parser.parse_args()
    root = args.root.resolve()

    try:
        installed_version = version("jsonschema")
        if installed_version != EXPECTED_JSONSCHEMA_VERSION:
            raise RuntimeError(
                "jsonschema version "
                f"{EXPECTED_JSONSCHEMA_VERSION} is required; found {installed_version}. "
                "Install requirements-governance.txt in an isolated environment."
            )
        from jsonschema import Draft202012Validator, FormatChecker
        from jsonschema.exceptions import SchemaError
    except (ImportError, PackageNotFoundError, RuntimeError) as error:
        print(f"JSON Schema validation unavailable: {error}", file=sys.stderr)
        return 2

    pairs = (
        ("governance-manifest.json", "schemas/governance-manifest.schema.json"),
        ("tests/governance-scenarios.json", "schemas/governance-scenarios.schema.json"),
        ("tests/routing-evaluations.json", "schemas/routing-evaluations.schema.json"),
        (
            "tests/routing-evaluation-run.template.json",
            "schemas/routing-evaluation-run.schema.json",
        ),
        (
            "tests/capability-evaluations.json",
            "schemas/capability-evaluations.schema.json",
        ),
        (
            "templates/CAPABILITY-EVALUATION-RUN.json",
            "schemas/capability-evaluation-run.schema.json",
        ),
    )
    failures: list[str] = []
    loaded: dict[str, tuple[Any, Any]] = {}
    format_checker = FormatChecker()

    for instance_relative, schema_relative in pairs:
        try:
            instance = load_json(root / instance_relative)
            schema = load_json(root / schema_relative)
            Draft202012Validator.check_schema(schema)
            validator = Draft202012Validator(
                schema,
                format_checker=format_checker,
            )
            errors = sorted(
                validator.iter_errors(instance),
                key=lambda error: tuple(str(part) for part in error.absolute_path),
            )
            if errors:
                for error in errors:
                    location = "/".join(str(part) for part in error.absolute_path)
                    failures.append(
                        f"{instance_relative} at {location or '<root>'}: {error.message}"
                    )
            else:
                print(f"PASS {instance_relative} against {schema_relative}")
            loaded[instance_relative] = (instance, schema)
        except Exception as error:  # validator/reference errors must fail closed
            failures.append(f"{instance_relative} / {schema_relative}: {error}")

    manifest_instance, manifest_schema = loaded.get(
        "governance-manifest.json",
        (None, None),
    )
    if manifest_schema is not None:
        malformed_schema = copy.deepcopy(manifest_schema)
        malformed_schema["properties"]["schema_version"]["type"] = (
            "not-a-json-schema-type"
        )
        try:
            Draft202012Validator.check_schema(malformed_schema)
            failures.append("self-test: malformed nested schema keyword was accepted")
        except SchemaError:
            pass

        dangling_schema = copy.deepcopy(manifest_schema)
        dangling_schema["properties"]["project_profile"]["$ref"] = (
            "#/$defs/does-not-exist"
        )
        try:
            list(
                Draft202012Validator(dangling_schema).iter_errors(
                    manifest_instance
                )
            )
            failures.append("self-test: dangling local $ref was accepted")
        except Exception:
            pass

        unknown_property_instance = copy.deepcopy(manifest_instance)
        unknown_property_instance["untrusted_override"] = True
        unknown_errors = list(
            Draft202012Validator(manifest_schema).iter_errors(
                unknown_property_instance
            )
        )
        if not unknown_errors:
            failures.append("self-test: unknown manifest property was accepted")

    if failures:
        print(
            f"JSON Schema validation FAILED with {len(failures)} finding(s).",
            file=sys.stderr,
        )
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(
        "JSON Schema validation PASS: 6 schemas meta-valid, "
        "6 canonical artifacts valid, rejection self-tests passed."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
