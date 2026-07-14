---
name: refactoring-mechanic
description: Use when modifying existing code structure without changing behavior — renaming, extracting, splitting modules, simplifying conditionals, or preparing for a feature. Activates during any structural change to existing code. Prevents "one big refactor" that breaks the build for days.
---

# Refactoring Mechanic

Engage when: changing organization not behavior (else use staff-architect); change is >50 lines or crosses >1 module. If tempted to "fix while I'm here" — separate behavior change from structural change.

## Execution Protocol

### Step 1: Characterize Before Touching
If code lacks test coverage: write characterization tests capturing current behavior (even if buggy), run green, commit. Never refactor code you cannot prove still works.

### Step 2: Identify Seams
Find the closest seam (preprocessing, link, or object) to your change. Inject there to minimize blast radius. If no seam exists, create one: extract interface, introduce parameter, or wrap the legacy unit.

### Step 3: The Mikado Method
For changes that would break the build if done at once:
1. Write the goal node.
2. Attempt directly; if it breaks, revert — don't fix forward.
3. The breakage reveals prerequisites. Create prerequisite nodes.
4. Recurse: each prerequisite must be achievable without breaking the build.
5. Work from leaves inward; only commit green states.

### Step 4: Preparatory vs. Opportunistic
- **Preparatory** — before adding a feature; scope only what's needed for the feature; refactor first, then trivial feature commit.
- **Opportunistic** — when already touching code; Boy Scout rule; if cleanup exceeds original change size, split to separate commit. Never refactor code you're not otherwise changing.

### Step 5: Preserve Behavior Rigorously
Green before → one mechanical change (rename, extract, inline, move, split/merge conditionals, isomorphic type change) → green after → atomic commit. Prohibited during pure refactor: changing logic branches, adding/removing null checks, changing access modifiers to "fix" tests, removing "unused" code without understanding it (Chesterton's Fence).

### Step 6: Validate
Static analysis (lint, type check, compile). Review diff — should be mechanical; any logic change is suspect. Cross-module refactorings need integration verification.

## Hard Rule
A refactoring that breaks tests is either (a) not a pure refactoring, or (b) tests coupled to structure. In case (a), separate the behavior change. In case (b), fix tests to test behavior, not structure, then refactor.
