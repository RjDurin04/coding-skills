---
name: debugging-strategist
description: Use when diagnosing a bug, failing test, regression, unexpected result, or intermittent behavior. Build and test causal hypotheses, automate reproduction when feasible, and report calibrated confidence instead of guessing or demanding impossible exhaustive falsification.
---

# Debugging Strategist

Keep diagnosis separate from implementation unless the requested task includes a
fix.

## 1. Preserve The Observation

Record expected and observed behavior, exact error text, environment, version,
inputs, timing, scope, and the earliest known good and bad states. Distinguish a
product defect from a misunderstood requirement, test defect, configuration
drift, corrupt state, dependency change, or external failure.

If the symptom may be causing continuing security, privacy, financial,
data-integrity, or availability harm, separate incident containment from root
cause work. Escalate the impact, preserve evidence, and propose the smallest
reversible observable containment under the applicable authority; urgency does
not authorize production mutation or broad access to customer, provider, or
financial records.

## 2. Reproduce Proportionally

Create the smallest automated reproduction when feasible and safe. If the issue
depends on production-only state, timing, hardware, or an external system, use a
controlled and authorized observation or representative harness and state what
remains unreproduced. Lack of automation lowers confidence; it does not prove
lack of understanding.

## 3. Test Causal Hypotheses

For each plausible hypothesis, state:

- the predicted evidence;
- evidence that would weaken it;
- the cheapest safe discriminating check;
- the current confidence and basis.

Inspect boundaries to find the first meaningful divergence. Check code, data,
configuration, permissions, dependency versions, concurrency, clocks, caches,
deploy deltas, and external systems as relevant. Use history or bisection when a
known-good range exists, without discarding unrelated work.

## 4. Conclude Honestly

Report causal confidence with the core certainty labels:

- `[VERIFIED] cause`: direct evidence establishes the causal chain;
- `[INFERRED] cause`: evidence strongly supports it but a material link remains;
- `[UNKNOWN] cause`: evidence does not yet distinguish the leading hypotheses.

Explain how the cause produced the symptom and any supported systemic
contributor. Do not require Five Whys or claim every alternative was falsified.

When fixing is authorized, add a regression test when feasible. If exact
reproduction is impractical, test the violated invariant or closest controlled
failure mode and disclose the gap.

## Hard Rules

- Do not change code merely to see whether the symptom disappears.
- Do not call correlation a verified root cause.
- Do not claim certainty beyond the reproduction and evidence.
