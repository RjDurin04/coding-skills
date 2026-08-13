---
name: safe-release-conductor
description: Use for release planning, release-readiness assessment, CI/CD or deployment design, shared-environment rollout execution, and post-release verification. Keep planning and read-only assessment distinct from execution; they never authorize mutation, and execution requires explicit authority.
---

# Safe Release Conductor

## 1. Classify The Governance Mode

Use the core task modes rather than inventing a release-specific authority:

- release planning is `DESIGN`;
- read-only readiness assessment and post-release observation are `REVIEW`;
- repository changes to CI/CD, deployment code, or release configuration are
  `IMPLEMENT`;
- shared-environment rollout, promotion, flag changes, rollback, or other
  mutation is `OPERATE`.

Compound requests must cross these boundaries explicitly. Re-route before each
transition. Planning, assessment, generated scripts, and readiness advice do not
authorize execution; read-only observation becomes `OPERATE` before any
corrective mutation.

## 2. Identify The Release Unit

Resolve the exact artifact or commit, target environment, configuration and
schema versions, included changes, owner, blast radius, dependencies, and
reversible or irreversible steps. Prevent a successful build of one artifact
from being mistaken for evidence about another.

## 3. Plan And Assess Proportionally

Check applicable evidence for:

- scoped CI, tests, static analysis, and security checks;
- artifact integrity, provenance, dependency state, and reproducible build path;
- configuration, secrets, permissions, feature flags, and environment drift;
- migration compatibility, backups, reconciliation, and rollback or roll-forward;
- capacity, cost, availability, observability, health checks, and alert coverage;
- runbook, support window, escalation path, and likely failure modes.

For orchestrated workloads, distinguish startup, liveness, readiness, and
serving/dependency health. A liveness probe should detect an unrecoverable local
process, not restart healthy instances because a dependency is down. Readiness
must remove traffic before shutdown or unsafe dependency loss, and rollout
timing must include startup, drain, termination, and in-flight work.

Choose direct, rolling, canary, blue-green, shadow, flag-controlled, or other
delivery based on consequence, traffic, observability, state compatibility, and
recovery speed. Do not require a progressive pattern when a bounded direct
release is safer, and give temporary flags an owner and removal condition.

Predeclare stop or rollback criteria from approved SLOs, verified baselines, and
business or security invariants. Proposed thresholds remain candidates until
approved.

## 4. Execute Only With Authority

Before execution, verify the exact target and artifact, approved scope, expected
effects, recovery path, and required confirmation. Preview or dry-run when
supported. Stop on unexpected scope, partial mutation, failed health evidence,
or changed assumptions; preserve evidence and report actual state.

Do not infer permission to deploy, promote, toggle, migrate, scale, or roll back
from requests to implement, prepare, review, or make something ready.

## 5. Observe And Report

Verify user-visible and system invariants over an observation window justified
by traffic and failure latency. Record the released artifact, target, time,
checks, signals, and any mutation or recovery performed.

Report task outcome, release readiness, and execution state separately. A
readiness pass is not proof that execution occurred; a successful command is not
proof that the release is healthy.
