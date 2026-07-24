---
name: operational-resilience
trigger: model_decision
description: Apply to production-facing runtime behavior, infrastructure, incidents, releases, and readiness evidence. Covers objectives, capacity, recovery, containment, and ownership.
---

# Operational Resilience

Production behavior is a property of the running system, its dependencies, and
its operators—not source code alone. Apply proportionally.

## Trigger

Services, APIs, workers, schedulers, queues, integrations, production data paths,
infrastructure, release design/execution, active incidents, high-volume flows,
or readiness claims.

## 1. Objectives And Detection

- Name the user-visible outcome and applicable availability, latency,
  correctness, freshness, durability, or completion SLI/SLO.
- Use accepted project requirements. Label proposed thresholds `CANDIDATE`; do
  not invent an SLO, error budget, RTO, or RPO and present it as approved.
- Define degraded/down behavior and evidence that detects material impact.
- Every alert needs a purpose, owner/recipient, threshold/window, and response or
  runbook. Non-alert telemetry needs a named diagnostic, audit, capacity, or
  product purpose and suitable retention; not every useful signal pages someone.

## 2. Capacity, Saturation, And Cost

- Name expected/peak workload, growth horizon, concurrency, payload/data size,
  and dependency quotas when known; mark unknowns.
- Bound queues, retries, fan-out, buffers, caches, connections, worker
  concurrency, and cost. Define overload/backpressure/degraded behavior.
- Inherit accepted infrastructure/API/storage/egress/AI budgets or propose
  labeled candidates with an owner and validation plan.
- Use representative load, profiling, query plans, or production metrics when a
  claim depends on capacity.

## 3. Recovery And Continuity

- Identify source-of-truth state and failure domains that can lose or corrupt it.
- Define backup scope, retention, encryption, access, and restore verification.
  A backup without a tested restore is unverified recovery.
- Use approved RTO/RPO for material state, or report them unknown/candidate.
- Assign recovery and communication owners. Rehearse restore/failover
  proportionally and record artifact, environment, and evidence time.
- Include relevant dependency outage, zone/region loss, credential compromise,
  operator error, and partial-state recovery.

## 4. Configuration, Build, And Artifacts

Apply `rules/configuration-and-feature-flags.md` for runtime configuration and
rollout controls. Apply `rules/supply-chain-and-build-integrity.md` for
dependencies, repository build execution, provenance, artifacts, and
vulnerability response. This rule consumes their findings rather than
duplicating their checklists.

## 5. Incident Containment And Recovery

During active material impact, a scoped, reversible, observable containment may
precede root-cause correction when delay would cause greater harm. It must:

- have the operational authorization and fresh confirmation required by
  `rules/agent-operation-safety.md`;
- name the exact target, expected harm reduction, blast radius, abort signal,
  rollback/recovery path, owner, and expiry/removal condition;
- preserve evidence and protect security, privacy, tenancy, and data integrity;
- be monitored for both mitigation and new harm;
- be labeled `CONTAINMENT` or `MITIGATION`, never permanent resolution;
- create an owned follow-up for root cause, durable correction, regression
  evidence, and removal/revalidation before expiry.

An unsafe or irreversible workaround is not justified merely by urgency.

## 6. Release Readiness And Execution

- Document likely failure modes, triage signals, rollback/roll-forward,
  escalation, and communication ownership.
- Predeclare abort/continue signals using accepted invariants, service
  objectives, saturation, cost, and data/security controls.
- A readiness assessment uses `rules/production-readiness-gate.md`.
- Shared/production execution uses `OPERATE`. Production releases and material
  or difficult-to-recover shared mutations require fresh confirmation; bounded
  reversible shared operations use the confirmation composed from their
  matching signals. If repository edits are needed, return to `IMPLEMENT`,
  verify, then re-enter `OPERATE`.

## Delivery Contribution

Record material objective/capacity/recovery/incident evidence, containment
owner/expiry, unverified target assumptions, blockers, and operational approval.
Do not merge task outcome, readiness, and external-action status.

## Release Blockers

Block `READY` when a material outcome has no detection, critical state lacks a
verified recovery path, expected load can exhaust an unbounded resource, active
containment is ownerless/expired/unsafe, or release/incident ownership is
unknown.
