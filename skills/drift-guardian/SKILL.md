---
name: drift-guardian
description: Use during implementation to prevent architectural erosion. Checks boundaries, dependency direction, duplication, and convention drift before and after code changes.
---

# Drift Guardian

Engage when:

- The project has more than one module, feature area, package, layer, or contributor.
- You add a dependency or import from a new area.
- You duplicate logic that may already exist.
- You modify a large file, public API, or shared abstraction.
- The change crosses domain, infrastructure, UI, data, or service boundaries.

## Step 1: Boundary Scan

Before writing code, identify:

- Which module, feature, bounded context, or layer owns the change.
- Which dependencies are allowed by existing architecture.
- Which public interfaces must be used instead of internal files.
- Which ADRs, docs, tests, or conventions govern this area.

If ownership or dependency direction is unclear and the ambiguity is material, ask. If risk is low, make a small `[ASSUMED]` choice and disclose it.

## Step 2: Dependency Direction

Follow the project's actual architecture. If the project has no documented architecture, infer local conventions from nearby code before adding structure.

Common defaults when they fit the codebase:

- Domain code should not depend on framework, database, transport, or UI details.
- Application/use-case code may depend on domain contracts.
- Infrastructure implements ports/adapters and depends inward.
- Sibling modules communicate through explicit public interfaces.
- Circular dependencies are design smells.

Do not impose a DDD/layered structure on a project that does not use it.

## Step 3: Duplication And Abstraction Check

Before adding a helper or duplicating logic:

- Search for existing behavior.
- Prefer existing local utilities when they fit.
- Keep one-off logic inline when it is clearer.
- Extract only when there is repeated pressure, a named invariant, or a boundary to protect.

## Step 4: Fitness Function

For structural changes, propose or add a guard that prevents future drift:

- Import-boundary test.
- Lint/static rule.
- Architecture test.
- Contract test.
- Documentation/ADR when automation is not practical.

## Step 5: Stop On Boundary Workarounds

When tempted to bypass a boundary, import internals, duplicate policy logic, or add a "temporary" bridge:

1. Name the tension.
2. Compare the clean path and fast path.
3. Recommend the smallest safe path.
4. Escalate to an ADR or user decision if the choice is material.

## Output

```
Drift review: PASS | PARTIAL | RISK
Boundary/owner: [...]
Dependency direction: [...]
Duplication check: [...]
Guard added/proposed: [...]
Risk: BLOCKER | WARNING | NOTE - [...]
```

## Hard Rules

- Local architecture beats generic architecture advice.
- Do not create hidden coupling to finish faster.
- Do not add structure just to look organized.
- If the design is wrong, surface it instead of routing around it.
