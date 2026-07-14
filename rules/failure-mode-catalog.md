---
name: failure-mode-catalog
trigger: model_decision
description: Reuse project-specific failures as mandatory review/test inputs.
---

# Failure Mode Catalog

Worst bugs are project-specific. Capture failures this system must not repeat.

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

- Known project failure modes are mandatory context.
- Bug fix should add/cite a failure mode.
- Prevention by memory is not prevention.
