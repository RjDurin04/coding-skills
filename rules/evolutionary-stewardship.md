---
name: evolutionary-stewardship
trigger: model_decision
description: Apply when modifying existing systems, refactoring legacy code, or extending long-lived components. Prevents both reckless rewrites and cowardly tolerance of debt.
---

When touching existing code:

1. **Chesterton's Fence**: before removing/changing anything, understand why it exists. Read comments and tests; inspect history or blame when available and useful. If you cannot explain it at the required risk level, do not remove it.
2. **Incremental replacement by default**: compare a strangler/incremental path with rewrite and tolerance. Choose incremental replacement when it materially lowers migration and rollback risk; do not force a wrapper when the component is isolated and a bounded replacement is safer.
3. **Boundary isolation**: use an adapter or anti-corruption layer when an external/legacy model would otherwise create harmful coupling. Do not add an adapter without a concrete mismatch to isolate.
4. **Backward compatibility by default**: preserve public consumers where feasible. A breaking change requires an explicit consumer-impact plan such as coordination, compatibility window, migration tooling, or versioning—not versioning by reflex.
5. **Debt classification**:
   - **Deliberate + prudent**: exact scope, authorized acceptance, owner,
     expiry/review date, compensating controls, evidence, and payback plan, with
     no bypass of security, data integrity, authz, privacy, or production
     safety. Apply the accepted-risk lifecycle in `GEMINI.md`; do not call it
     production-ready unless the aggregate production gate passes.
   - **Deliberate + reckless**: "we know it's bad, shipping anyway" or any
     shortcut without owner/expiry/removal condition -> do not implement
     durably. Require a valid accepted-risk record; use an ADR only when the
     project already uses one for this class of decision.
   - **Accidental**: discovered debt -> report a proposed backlog item with an
     impact estimate. Create it in a repository only under `IMPLEMENT`, or in an
     external tracker only under an authorized `OPERATE` cycle.
6. **Refactor vs rewrite vs tolerate** decision:
   - Tolerate if: rarely touched, works, low risk
   - Refactor if: touched often, tests exist, scope is bounded
   - Rewrite only when the model is fundamentally wrong, the replacement boundary is understood, behavior is characterized, and migration/rollback risk is controlled

Never claim "the old code is bad" without evidence. Legacy code may be active,
unused, degraded, or faulty; establish its current behavior, consumers, and
constraints before replacing it.
