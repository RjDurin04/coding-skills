---
name: refactoring-mechanic
description: Use when changing the structure of existing code without intending to change observable behavior, such as renaming, moving, extracting, splitting, inlining, or simplifying. Preserve behavior with evidence proportional to risk and never commit, revert, reset, or discard work without authorization.
---

# Refactoring Mechanic

## 1. Define The Behavior Boundary

State the observable behavior that must remain stable: public contracts, errors,
side effects, persistence, events, timing-sensitive guarantees, and caller
expectations. Separate any intentional behavior correction into an explicit
change with its own tests and review.

Inspect relevant callers, tests, local conventions, generated-code boundaries,
and uncommitted changes before editing. Preserve unrelated work.

## 2. Establish A Proportional Baseline

Use the strongest practical combination of existing behavior tests, focused
characterization tests, type or static checks, contract fixtures, snapshots, and
controlled runtime observations. Add characterization coverage where the risk
and current evidence justify it; do not create broad brittle tests merely to
permit a mechanical edit.

If current behavior is unclear or suspected to be wrong, record that uncertainty
instead of silently enshrining it as the desired contract.

Proceed only when the baseline can detect material changes at the boundary being
moved, or when the transformation is genuinely mechanical and a compiler,
typechecker, or equivalent check covers that claim. Otherwise narrow the
refactor, add characterization, or stop with the gap visible. A deadline cannot
turn inadequate preservation evidence into success.

## 3. Refactor In Reviewable Steps

- Choose seams that minimize callers and ownership changes.
- Prefer mechanical transformations with narrow diffs.
- Use a dependency map or Mikado-style prerequisite plan when a direct change
  would leave the tree broken for too long.
- Keep preparatory refactoring scoped to the requested capability.
- Stop and reclassify the task when logic, access, validation, persistence, or
  error behavior must change.

Validate after each cohesive risk-bearing increment. Do not commit, reset,
revert, checkout, or discard changes unless the user authorized that operation.
If an exploratory edit fails, restore only the changes you introduced after
verifying the exact target.

## 4. Verify Preservation

Run the relevant baseline again, then inspect the diff for accidental behavior,
contract, dependency, or generated-artifact changes. Cross-boundary moves need
contract or integration evidence; a local rename may need only compile, static,
and focused tests.

## Hard Rules

- Line count alone does not make a refactor safe or risky.
- A green suite proves only its covered behavior.
- A failing test may expose a behavior change, a structural-coupled test, or an
  invalid baseline; diagnose which before modifying either code or test.
