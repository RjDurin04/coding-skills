---
name: failure-mode-catalog
trigger: model_decision
description: Reuse recurring or high-consequence project failures as review, detection, and regression inputs.
---

# Failure Mode Catalog

Some project failures deserve durable organizational memory. Catalog only a
recurring class, a high-consequence incident/near miss, a subtle systemic
failure likely to recur, or a failure needed by a runbook/compliance control.
Ordinary one-off bugs still need appropriate regression evidence but do not
automatically need a catalog entry.

## Entry Decision

An entry is warranted when at least one is true:

- the failure recurred or represents a reusable class across code paths;
- impact is material security, privacy, data integrity, money, outage, safety,
  or compliance harm;
- detection/prevention spans more than the local regression test;
- incident learning or an accepted-risk record must remain visible.

Otherwise keep the finding in the issue/test/change record. In `REVIEW`,
`DIAGNOSE`, or `DESIGN`, report or propose the entry without creating it.
Create or update a repository record only in an authorized `IMPLEMENT` cycle;
writing an external tracker or runbook service requires the corresponding
authorized `OPERATE` cycle.

## Storage

Use existing risk/runbook/ADR/test docs; else `docs/failure-modes.md` if docs
exist; else final-response note. Do not create new docs structure unless the
project already uses docs or the task is structural/critical.

## Entry

```
Area: [...]
Failure: [concrete bad outcome]
Trigger: [...]
Impact: [data loss | money | security | outage | UX | compliance]
Detection: [test | metric | log | alert | support]
Prevention: [constraint | transaction | idempotency | authz | validation | retry | runbook]
Status: ACTIVE | MITIGATED | ACCEPTED
Accepted risk: [valid accepted-risk record/reference | N/A]
```

## Use

When touching related code: treat entry as regression-test candidate; verify
prevention still exists; add detection if failure would be invisible; update entry
if risk changes.

Seeds: payment double-charge/refund/currency/webhook replay; auth session fixation/
token replay/role escalation/UI-only authz; data cascading delete/soft-delete
leakage/timezone drift/cross-tenant leakage; integration rate limit/reordering/
duplicates/partial outage; scale queue backlog/unbounded export/N+1/cache stampede.

## Delivery Contribution

Add only reused/updated failure modes, related tests/detection, and material risk
to the unified delivery record in `GEMINI.md`.

## Hard Rules

- Related known high-consequence/recurring failure modes are mandatory context.
- A bug fix adds/cites a catalog entry only when the entry decision applies.
- `Status: ACCEPTED` is invalid without a current accepted-risk record containing
  the owner, approval source, exact scope, worst credible outcome, compensating
  controls, evidence, expiry/review date, and rollback/remediation required by
  `GEMINI.md`.
- Prevention by memory is not prevention.
