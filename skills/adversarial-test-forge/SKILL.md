---
name: adversarial-test-forge
description: Use when behavior has meaningful input, state, concurrency, external-system, security, data-integrity, or business risk and tests should try to falsify important claims. Select test techniques and case depth from concrete failure modes rather than branch count, fixed property quotas, or universal runtime thresholds.
---

# Adversarial Test Forge

## 1. Identify What Must Fail Safely

Map the protected invariants, trust boundaries, state transitions, side effects,
limits, and likely bug magnets. Rank cases by consequence, plausibility, current
coverage, and cost to detect later. Do not engage merely because a function has
more than one branch.

Consider as relevant:

- empty, missing, malformed, duplicate, oversized, encoded, and boundary input;
- unauthorized role, object, field, tenant, or operation;
- wrong order, retry, replay, cancellation, concurrent execution, and recovery;
- time zones, clock changes, precision, overflow, pagination, and limits;
- timeout, partial response, unavailable dependency, stale cache, failed write,
  and partial commit;
- invariant violations and previously observed regressions.

## 2. Choose The Right Test Surface

Select unit, integration, contract, end-to-end, property-based, fuzz,
state-machine, concurrency, mutation, or fault-injection tests according to the
boundary and risk. Do not require every technique or a fixed number of
properties per function.

Prefer the lowest test layer that provides direct evidence for the behavior,
then add cross-boundary evidence where mocks would hide the failure. Use
production-like dependencies only in an authorized, isolated environment.

## 3. Keep Evidence Reliable

- Control time, randomness, scheduling, network, and shared state where the test
  contract permits.
- Follow the repository's test performance budgets; do not impose a universal
  sub-100 ms rule.
- Make failures identify the broken invariant and relevant input.
- Avoid redundant cases that exercise the same path without increasing
  confidence.
- Bound fuzzing, concurrency, payloads, and fault injection to avoid unsafe
  resource use.

For a bug fix, reproduce with a failing regression test first when feasible. If
the original environment or timing cannot be reproduced safely, test the
violated invariant or nearest controlled failure mode and disclose the gap.

## 4. Report Coverage Honestly

State the claims exercised, techniques used, important cases omitted, fixture or
environment limits, and remaining risk. Passing adversarial tests supports only
the tested state space; it does not prove the absence of defects.
