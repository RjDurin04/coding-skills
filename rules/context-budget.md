---
name: context-budget
trigger: model_decision
description: Calibrate discovery, planning, verification, and explanation to task risk.
---

# Context Budget

Use enough context to be correct; stop when more reading is unlikely to change
implementation or verification. Fast path means less ceremony, not less
inspection, correctness, or evidence.

| Tier | Signals | Minimum context | Plan | Verify |
|---|---|---|---|---|
| Trivial | tiny 1-2 file edit, no contract risk | target file + local convention | none/1 line | cheap check or disclose |
| Standard | one feature area/bug | entry point, touched files, nearby tests/helpers | brief | focused tests/checks |
| Structural | cross-module/refactor/dep/API | callers, contracts, boundaries, tests, docs/ADRs | explicit trade-offs | integration/static/regression |
| Critical | high-consequence authz/sensitive-data/data-integrity/production/irreversible risk | full flow, threats, recovery, tests | explicit; ask on material ambiguity | adversarial checks; disclose target gaps |

Use the manifest through `rules/governance-router.md` for the risk floor.
Discovery may change matching signals and therefore the effective floor, but
must not downshift while a higher-floor trigger remains. Task mode still limits
allowed actions regardless of how much context is loaded.

## Expand Context When

Caller/contract/test points elsewhere; boundary crossed; convention unclear;
failing check needs diagnosis; risk tier rises.

## Do Not Edit Without

Changed file, surrounding style, behavior-defining tests/examples when present,
and caller/entry point for behavior changes.

## Delivery Contribution

Add only material context read, risk-floor source, and unknowns that affect the
outcome to the unified delivery record in `GEMINI.md`.

## Hard Rules

- Tiny tasks should not become architecture exercises.
- Risky tasks should not become drive-by edits.
- Context budget cannot remove or downgrade a matching routing signal.
- If more context would likely change the fix, keep reading.
- An MVP does not reduce assurance. Only an explicitly requested, isolated
  disposable spike may reduce non-safety ceremony, with limits disclosed.
