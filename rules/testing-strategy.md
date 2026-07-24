---
name: testing-strategy
trigger: model_decision
description: Applies to code changes, bug fixes, refactors, critical flows, and behavior changes. Scales tests to risk.
---

# Testing Strategy

Tests are evidence. Falsify likely failures, not implementation details.

## Tier

| Tier | Use when | Coverage |
|---|---|---|
| Minimal | trivial glue/copy, no logic | existing check or focused assertion |
| Standard | normal feature/fix with branches/collaborators | happy path, edge cases, regression risk |
| Exhaustive | credible high-consequence data/financial/authz/security/concurrency/migration flow | negative paths, invariants, failure injection, integration |

## By Change Type

- Bug fix: failing regression first unless impractical; must fail before/pass after
  or the gap is at least `WARNING`.
- Feature: caller/user-visible behavior, branches, validation, permission, failure.
- Refactor: behavior preserved; characterize first if coverage is weak.
- Public API: compatibility, serialization, validation, error shape, caller contract.
- Persistence: constraints, transactions, rollback/partial failure, scope, invariants.
- UI: relevant loading, empty, error, partial, success, disabled, keyboard, a11y, responsive.
- Performance: query-count, benchmark, complexity assertion, representative fixture, or monitoring guard.

## Edge Checklist

Use relevant cases only: empty/null/missing/zero/negative/limit-1/limit/limit+1/
max; unicode/whitespace/case/locale/timezone/DST/clock skew; duplicate/retry/
replay/out-of-order/concurrent; partial failure/timeout/dependency down/malformed
response; denied/wrong role/wrong tenant/object/expired session; large input,
deep pagination, high fan-out, memory pressure.

## Quality Rules

Tests must be deterministic, focused, clear on failed contract, fast where
possible, and consistent with existing fixtures/helpers/style.

## Acceptable No-Test Cases

Docs/comments/formatting/trivial copy; exact behavior already covered; no harness
and creating one exceeds scope. An explicitly requested, isolated disposable
spike/prototype may omit tests only when they are not needed to establish its
bounded learning goal or mandatory authorization, security, privacy, or
data-integrity controls. This exception cannot support release readiness and
expires if the work is promoted into durable use. Disclose verification and
residual risk.

Finding and readiness severity for missing test evidence:
- Behavior-changing work without a focused test/check is at least `WARNING`.
- Auth, permission, tenant isolation, data integrity, migration, payment, or
  security-sensitive work without negative tests/checks is `BLOCKER` unless exact
  equivalent coverage is verified or current tooling makes the check impossible.
- Refactor without characterization or preservation evidence is at least
  `WARNING`; structural refactor without it is `BLOCKER`.
- A behavior, runtime, contract, security, or data change without relevant test
  or equivalent verification evidence cannot support a production-ready,
  shippable, or deployable claim. Docs-only/non-code artifacts are assessed by
  their applicable checks rather than forced code tests.

## Delivery Contribution

Add checks run, important behavior/risks covered, untested material paths, and
the resulting risk to the unified delivery record in `GEMINI.md`.

## Hard Rules

- Bug fix without regression test needs a reason.
- Critical flows need negative tests, not only happy paths.
- Refactors must be behavior-preserving and verified when possible.
- Missing tests for behavior/security/data risk must carry the risk floor above.
- Do not change production code to satisfy a brittle test before checking the contract.
