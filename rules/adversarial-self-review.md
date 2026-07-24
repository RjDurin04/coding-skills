---
name: adversarial-self-review
trigger: model_decision
description: Final quality gate before delivering code, design, plan, or review.
---

# Adversarial Self-Review

Before delivery, try to find the defect that will matter later.

## Attack Angles

- Requirement: solved actual request, not nearby problem?
- Routing: did risk floor match task signals, and were required gates/skills loaded?
- Regression: what existing behavior can break?
- Approach: did we choose the right architecture, algorithm, data structure, and local pattern?
- Shortcut: did we hardcode, duplicate, bypass a boundary, or leave a temporary path without explicit request?
- Security: input/auth/rendering/files/URLs/deps/secrets/races abuse?
- Reliability: network/disk/DB/queue/clock/dependency/process failure?
- Scale: 100x data, fan-out, deep pages, retry storms, many tenants?
- Maintainer: clear during an incident?
- Contract: types, returns, errors, side effects, public behavior match?
- Grounding: are APIs, packages, fields, routes, helpers, and configs verified in code/docs?
- Test: would checks fail if subtly wrong?

## Evidence

Support each material claim with an inspected code path, test/check result,
type/lint/build, manual/browser check, query plan/benchmark/profile, security
review/negative test, or explicit unverified gap. Record the relevant
environment/scope and evidence time/version. No evidence means weaken the claim
or run a check.

## Fix Or Disclose

Fix in-scope findings. Otherwise label: `BLOCKER` must resolve before relying/
release; `WARNING` address soon/before broad use; `NOTE` useful follow-up.

## Delivery Contribution

Add fixed material findings, remaining gaps, evidence, and final risk to the
unified delivery record in `GEMINI.md`. Do not emit a standalone self-review
transcript by default.

## Hard Rules

- No silent known issues.
- Do not exceed evidence.
- Missed applicable governance routing is a finding, not a pass.
- Ungrounded APIs/packages/fields/routes/contracts are defects.
- Happy-path-only tests are insufficient for critical logic.
- MVP scope does not lower production assurance. Prototype shortcuts are
  acceptable only for an explicitly requested, isolated disposable spike with
  disposal criteria and must remain findings if promoted into durable work.
- Accepted risk without exact scope, authorized owner, compensating controls,
  evidence, and unexpired review/remediation date is a finding.
