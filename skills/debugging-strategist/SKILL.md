---
name: debugging-strategist
description: Use when investigating any bug, test failure, unexpected behavior, or regression. Activates during VERIFY phase, in observability work, or when user says "this is broken", "tests are failing", "it worked before". Replaces guess-and-check with disciplined hypothesis-driven diagnosis.
---

# Debugging Strategist

Engage when: expected ≠ actual behavior; you have a stack trace, failing test, or error message; you're tempted to change code "to see if it fixes it."

**Prohibition:** Never commit a fix you cannot explain.

## Execution Protocol

### Step 1: Minimal Reproduction
Create the smallest automated reproduction (test, script, curl). Strip dependencies, data, and time until removing any single element makes the bug disappear. If you can't automate it, you don't understand it enough.

### Step 2: Define the Possibility Space
Map symptom to cause categories: code defect (logic, off-by-one), state corruption (race, stale cache), environment drift (dependency, config, infra), misunderstanding (code works as designed), external system (API, DB, network).

### Step 3: Hypothesis-Driven Binary Search
For each hypothesis, define: predicted evidence if TRUE, falsifying evidence if FALSE, exact test to perform. Run cheapest first; halve the possibility space each iteration. Differential diagnosis: if X were true I'd see A. I see ¬A. Therefore ¬X. Accept only when all competing hypotheses are falsified.

### Step 4: Bisection for Regressions
Identify known-good and known-bad commits; bisect (`git bisect` or manual) until first bad commit isolates the change. If regression correlates with a deployment, compare the delta.

### Step 5: State Inspection Strategy
Snapshot at boundaries (input → intermediate → output). Diff expected vs actual to find first divergence. Check invariants — the first broken invariant is the fault line. For ordering bugs, log exact event sequence with timestamps.

### Step 6: Root Cause Definition
Stop when you can answer: what exact line/state is wrong; why; how it propagated; systemic cause (Five Whys). Not done until you can write a regression test that fails before the fix and passes after.

## Hard Rule
Guessing is not debugging. If you change code without a falsifiable hypothesis, you are not debugging — you are hoping.
