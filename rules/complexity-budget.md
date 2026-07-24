---
name: complexity-budget
trigger: model_decision
description: Apply before adding material abstractions, dependencies, shared or public boundaries, ownership surfaces, architecture, or broad coordinated structure.
---

# Complexity Budget

Complexity must buy correctness, clarity, safety, performance, or cheaper future
change. Judge cohesion, coupling, ownership, and lifecycle cost—not raw counts.

## Orientation Heuristics

These are prompts for review, not quotas, ceilings, or release gates:

| Tier | Typical shape | Required justification |
|---|---|---|
| Trivial | Usually no new abstraction/dependency and at most one local file | Explain any durable structure. |
| Standard | Usually a small number of cohesive edits and no new boundary | Name the owner and why existing structure does not fit. |
| Structural | New/shared boundary, dependency, or several coordinated modules may be correct | Justify each durable ownership/dependency surface and migration cost. |
| Critical | Prefer the smallest auditable design that enforces critical invariants | Demonstrate boundary enforcement, failure handling, recovery, and review ownership with scoped evidence. |

Never pack unrelated responsibilities into a large file, collapse useful
boundaries, avoid tests, or choose an unsafe bespoke implementation merely to
stay under a count.

## Spend Only For Real Pressure

Valid pressure includes repeated logic with the same invariant and real callers;
a boundary isolating domain from external/legacy concerns; a stable public
contract owner; workload-required data structure/algorithm; or a test seam for
material behavior.

Invalid pressure includes "might be useful", copying another project's shape,
framework-template folders without ownership, vague helpers that hide
responsibilities, or a convenience dependency whose lifecycle cost exceeds its
value.

## Dependencies

Minimize total lifecycle and security risk, not dependency count. Compare:
existing/local functionality; a small direct implementation; and a maintained,
appropriately scoped dependency. Check identity, maintenance, license,
advisories, transitive/install/native risk, version policy, runtime/bundle/ops
cost, and replacement path under
`rules/supply-chain-and-build-integrity.md`.

Do not hand-roll cryptography, authentication/authorization, security protocols,
or standards-heavy parsers merely to report zero dependencies. Bespoke code is a
dependency the project must own.

## When Complexity Grows

Re-check problem fit; split unrelated responsibilities; inline accidental
indirection; separate refactor from behavior; document durable ownership; and
escalate to architecture only when the pressure is real. More files can improve
cohesion; fewer files can reduce indirection. Neither is inherently simpler.

## Delivery Contribution

Record only material new boundaries, abstractions, configuration, files, or
dependencies; why they reduce total risk/cost; the simpler option considered;
and remaining ownership or migration risk.

## Hard Rules

- No abstraction without a concrete invariant, boundary, or repeated pressure.
- No broad refactor hidden in a feature/fix.
- No numeric-count compliance at the expense of cohesion, tests, or safety.
- If simpler is correct, safer, and maintainable, choose it.
