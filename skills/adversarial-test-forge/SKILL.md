---
name: adversarial-test-forge
description: Use when writing any logic that handles user input, external data, concurrent operations, or business-critical flows. Activates during or immediately after implementation. Generates tests designed to FALSIFY code — not prove it works, but actively try to break it. Produces unit, property-based, and chaos tests with explicit risk-based prioritization.
---

# Adversarial Test Forge

## Activation Procedure

Before writing tests, ask:
1. Does this code handle untrusted input?
2. Would a bug here cause data loss, financial loss, or security breach?
3. Does it involve concurrency, external state, or side effects?
4. Is it on the critical path for business value?
5. Does the logic have >1 branch or >1 collaborator?

If ≥1 is YES → engage. Trivial getters/setters and pure passthroughs are exempt.

## Execution Protocol

### Step 1: Score Risk
```
Impact if wrong: [Data loss | Money | Security | UX | Cosmetic]
Likelihood of bug: [High change freq | Complex logic | New dev | Third-party]
Test investment tier: [Exhaustive | Standard | Minimal]
```

### Step 2: Generate Falsification Tests
For each function/endpoint, cover:
- **Happy Path**: 1-2 tests (documentation only)
- **Boundary Attacks**: empty/null/zero/negative/max, unicode, limit±1
- **State Attacks**: wrong order, twice (idempotency), concurrently (races), after failure (recovery)
- **Invariants**: 2-5 property-based checks that MUST hold for any input
- **Failure Injection**: network timeout, DB unavailable, partial read/write, clock skew, disk full
- **Bug Magnets**: off-by-one, timezone/DST, float precision, null vs empty vs missing, case sensitivity, integer overflow

Tests must: use AAA structure, test ONE thing, be deterministic (no time.now, no real random, no network), fail with clear invariant message, run fast (<100ms unit tests).

### Step 3: Regression Seeding
When fixing any bug: the test comes first (proving the bug exists), then the fix.