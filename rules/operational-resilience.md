---
name: operational-resilience
trigger: model_decision
description: Apply to production-facing runtime behavior, infrastructure, releases, and readiness claims. Covers service objectives, capacity and cost, recovery, reproducibility, supply chain, and incident ownership.
---

# Operational Resilience

Production readiness is a property of the running system and its operators, not
only of source code. Apply each section proportionally and mark non-applicable
items with a concrete reason.

## Trigger

Services, APIs, workers, schedulers, queues, integrations, production data paths,
infrastructure/configuration, deployment/release work, high-volume flows, or any
production-ready/shippable/deployable claim.

## 1. Service Objectives And Detection

- Define the user-visible outcome and applicable SLI/SLO: availability, latency,
  correctness, freshness, durability, or completion time.
- Define what counts as down/degraded and how error-budget burn is detected.
- Give every actionable alert an owner, threshold, evaluation window, and
  response. Avoid alerts without an operator action.

## 2. Capacity, Saturation, And Cost

- Name expected and peak workload, growth horizon, concurrency, payload/data
  size, and dependency quotas.
- Bound queues, retries, fan-out, buffers, caches, connections, and worker
  concurrency. Define overload behavior and backpressure.
- Set or inherit budgets for infrastructure, third-party APIs, storage, egress,
  and AI/token usage. Detect abnormal spend before it becomes material.
- Use representative load, profiling, query plans, or production metrics when a
  claim depends on capacity.

## 3. Recovery And Continuity

- Identify source-of-truth state and the failure domains that can lose or corrupt
  it.
- Define backup scope, frequency, retention, encryption, access, and restore
  verification. A backup without a tested restore is unverified recovery.
- Define RTO and RPO for material state; assign recovery and communication owners.
- Rehearse restore/failover proportionally and record the last evidence. Include
  dependency outage, region/zone loss, credential compromise, and operator error
  when relevant.

## 4. Build And Infrastructure Reproducibility

- Lock inputs according to the stack and retain enough provenance to reproduce
  or explain an artifact.
- Detect configuration/environment/IaC drift. Review manual production changes
  and either codify or revert them.
- Keep secrets outside source/artifacts, support rotation, and document the
  effect of rotation on running workloads.
- Verify architecture-specific state assumptions; do not force stateless or
  twelve-factor design where it does not fit.

## 5. Supply Chain And Artifacts

- Verify dependency identity, advisories, maintenance, license compatibility,
  transitive/install-script/native risk, and the project's pin/lock policy.
- Produce or verify an SBOM for applicable releases. Preserve build provenance
  and sign artifacts when the delivery chain can verify signatures meaningfully.
- Run applicable secret, dependency, static, and dynamic security scans; diagnose
  findings rather than treating tool execution as proof of safety.

## 6. Incident And Release Readiness

- Document likely failure modes, triage signals, mitigation, rollback/roll-forward,
  escalation, and customer/support communication ownership.
- Predeclare release abort conditions using the system's SLOs, invariants, and
  saturation/cost signals.
- Verify authorization under `rules/agent-operation-safety.md` before mutating a
  shared environment.

## Delivery Contribution

Add material SLO/capacity/recovery/supply-chain evidence, unverified readiness
items, blockers, and owners to the unified delivery record in `GEMINI.md`.

## Release Blockers

Block readiness claims when a material service outcome has no detection, critical
state has no verified recovery path, expected load can exhaust an unbounded
resource, a critical supply-chain finding is unresolved, or incident/release
ownership is unknown.

