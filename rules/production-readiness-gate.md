---
name: production-readiness-gate
trigger: model_decision
description: Final verification before claiming work is shippable, deployable, safe to release, or production-ready.
---

Before saying "shippable", "deployable", "safe to deploy/release", or "production-ready", check every applicable item. Mark N/A with reason; disclose anything not run.

## Gate

- **Governance:** risk floor and triggered rules/skills were routed; standard+ decisions cite codebase evidence.
- **Requirements:** ASRs have acceptance criteria; code/tests trace to REQ/ADR.
- **Correctness:** unit edge cases, integration contracts, and regression tests for fixes.
- **Approach quality:** architecture, algorithm, data structure, and local pattern choices are justified; shortcut/prototype paths are absent or explicitly out of production scope.
- **Static quality:** build/lint/typecheck/format pass; complexity budget respected.
- **Performance/efficiency:** hot-path input sizes, asymptotic cost, query shape, indexes, memory bounds, batching/backpressure, and relevant benchmarks/profiling/metrics considered.
- **Failure handling:** explicit reject/retry/degrade/compensate/fail-fast behavior; timeouts, retries, idempotency, partial failure, and concurrency considered; contextual errors without secrets.
- **Security/privacy:** parse at trust boundaries; auth/authz, injection, SSRF, deserialization, races, and secret leakage reviewed; telemetry redacts sensitive data.
- **Data safety:** schema changes are backward-compatible or expand-contract; migrations have recovery; invariants enforced by constraints, transactions, tests, or compensation.
- **Observability:** logs/metrics/traces/health exist for non-trivial runtime behavior; maintainer can answer "working?", "affected?", and "changed?"
- **Service objectives:** applicable SLOs/SLIs, error-budget impact, capacity limits, saturation signals, and infrastructure/API/AI cost budgets are defined or explicitly not applicable.
- **Recovery:** backup scope, restore evidence, RTO/RPO, disaster-recovery ownership, and failover/restore rehearsal are proportionate to state criticality.
- **Supply chain:** dependency/advisory/license checks, lockfiles, SBOM, build provenance, and artifact signing are verified where applicable.
- **Build and infrastructure:** builds are reproducible enough for the release model; environment/IaC drift is checked; secrets and keys are managed and rotatable.
- **Operations:** env-driven config; an applicable rollback/roll-forward and blast-radius strategy; likely failure modes have owned runbook and escalation notes.
- **Authority:** production/shared-environment mutation is explicitly authorized under `rules/agent-operation-safety.md`.
- **Review:** adversarial self-review run; remaining risks labeled BLOCKER, WARNING, or NOTE.

Any `BLOCKER` from governance routing, testing, security, data integrity,
efficiency, release, or adversarial review means `NOT READY`.

## Delivery Contribution

Never claim shippable/deployable/safe-to-release/production-ready unless all
applicable checks are verified. Add `VERIFIED`, `PARTIAL`, or `NOT READY`, the
evidence, unverified checks, remaining risks, and required approval to the
unified delivery record in `GEMINI.md`.
