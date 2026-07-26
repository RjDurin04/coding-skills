---
name: production-readiness-gate
trigger: model_decision
description: Aggregate current domain-gate evidence before a production-ready, shippable, deployable, or safe-to-release claim.
---

# Production Readiness Gate

This gate assesses readiness; it does not restate every domain checklist and
does not authorize release execution.

## Trigger

Use when the user requests a readiness assessment or before claiming
production-ready, shippable, deployable, or safe to release. A release design or
configuration change without such a claim uses its domain gates. Actual
shared/production mutation separately enters `OPERATE` and
`rules/agent-operation-safety.md`.

## 1. Bind The Claim

Name the exact artifact, commit, image, package, or version; target environment;
intended workload/data class/tenant scope; release mechanism; assessment time;
and evidence sources. An unversioned or environment-free claim cannot be
`READY`.

## 2. Aggregate Triggered Gates

Use routing to identify applicable domain gates. For each, consume its latest
result rather than recreating its checklist. A domain rule need not emit a
standalone status during ordinary work; the aggregator maps its material
evidence and findings to the tuple below. If the evidence cannot establish a
result, use `UNVERIFIED` rather than inferring a pass:

```text
Gate: [rule/required project gate]
Status: PASS | FAIL | UNVERIFIED | N_A
Evidence: [artifact/check/source, environment, time]
Owner: [for remediation or accepted risk]
Reason: [required for FAIL, UNVERIFIED, or N_A]
```

At minimum, consider whether routing triggered requirements/contract,
correctness/testing, security/privacy, data integrity, efficiency/capacity,
observability/resilience/recovery, configuration/flags, supply-chain/build,
AI-safety, accessibility, and release/recovery evidence. Do not mark a domain
applicable merely to fill a template; do not omit one that routing triggered.

Confirm that:

- evidence refers to the same artifact and target assumptions and remains
  current after subsequent changes;
- unresolved BLOCKERs and failed critical/non-compensatory criteria are visible;
- accepted-risk records satisfy the owner, scope, controls, evidence, and expiry
  lifecycle in `GEMINI.md`;
- rollback/roll-forward and release abort evidence is proportional to impact;
- release execution authority is reported separately, never inferred from
  readiness.

## 3. Decide

- `READY`: every applicable material gate passes with current scoped evidence;
  accepted risks are valid and do not violate a non-exceptable invariant.
- `PARTIAL`: useful assessment exists, but material evidence is missing or stale.
  This is not permission to release.
- `NOT_READY`: an applicable gate failed, a BLOCKER exists, recovery is
  materially unsafe or unknown, or the artifact/target cannot be identified.
- `NOT_ASSESSED`: no readiness assessment was requested or completed.

Task outcome may be `COMPLETE` while readiness is `PARTIAL` or `NOT_READY`.
Readiness may be `READY` while external action remains
`AWAITING_AUTHORIZATION`.

An authorized, scoped incident containment under
`rules/operational-resilience.md` may proceed to reduce active harm even when a
normal release is not `READY`; report it as containment, preserve the readiness
gaps, and do not turn emergency authority into general release authority.

## Delivery Contribution

Report readiness status, artifact/target/time, aggregate gate evidence, blockers,
unverified items, accepted-risk expiry, and required human approval in the
unified delivery record. Never use affirmative production-ready, shippable,
deployable, or safe-to-release language when status is not `READY`.
