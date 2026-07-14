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
   - **Deliberate + prudent**: explicit user/stakeholder acceptance, owner,
     expiry/removal condition, payback plan, and no bypass of security, data
     integrity, authz, privacy, or production safety. Label as accepted debt;
     do not call it production-ready unless the production gate still passes.
   - **Deliberate + reckless**: "we know it's bad, shipping anyway" or any
     shortcut without owner/expiry/removal condition -> require ADR and explicit
     acceptance before durable implementation.
   - **Accidental**: discovered debt -> add to backlog with impact estimate.
6. **Refactor vs rewrite vs tolerate** decision:
   - Tolerate if: rarely touched, works, low risk
   - Refactor if: touched often, tests exist, scope is bounded
   - Rewrite only when the model is fundamentally wrong, the replacement boundary is understood, behavior is characterized, and migration/rollback risk is controlled

Never claim "the old code is bad" without evidence. Legacy code is code that works in production — respect it before replacing it.
