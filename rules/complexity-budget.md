---
name: complexity-budget
trigger: model_decision
description: Apply before adding abstractions, files, dependencies, configuration, architecture, or broad structure.
---

# Complexity Budget

Complexity must buy correctness, clarity, safety, performance, or cheaper future
change. Defaults are ceilings, not quotas.

| Tier | Abstractions | Files/modules | Dependencies | Tests |
|---|---:|---:|---:|---|
| Trivial | 0 | 0-1 | 0 | existing/minimal |
| Standard | 0-1 | 0-3 | 0 | focused behavior |
| Structural | justify each | justify each | 0 unless strong case | regression/integration |
| Critical | minimize/prove | minimize/prove owner | avoid unless reviewed | adversarial/risk-driven |

## Spend Only For Real Pressure

Valid: repeated logic with same invariant and real callers; boundary protecting
domain from infra/external/legacy; stable public contract owner; workload-required
algorithm/data structure; test seam for important behavior.

Invalid: "might be useful"; copying another project; vague helper hiding mess;
dependency for small convenience; framework-template folders/classes without need.

## Dependency Checklist

Before adding one: local/stdlib insufficient; identity/maintenance/license/security
acceptable; versioning follows project; runtime/bundle/ops cost acceptable;
replacement path understood. Unknown durable risk means do not add or disclose.

## If Exceeded

Re-check problem fit; inline/simplify accidental complexity; split refactor from
behavior; escalate to architecture only when complexity is essential.

## Delivery Contribution

Add material new abstractions/files/dependencies, their justification, the
simpler option rejected, and any exceeded budget to the unified delivery record
in `GEMINI.md`.

## Hard Rules

- Zero new dependencies by default.
- No abstraction without invariant, boundary, or repeated pressure.
- No broad refactor hidden in feature/fix.
- If simpler is correct and maintainable, choose it.
