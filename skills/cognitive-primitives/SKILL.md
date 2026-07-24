---
name: cognitive-primitives
description: Use as a supporting reasoning toolkit for non-trivial design, debugging, implementation, or review when state spaces, boundaries, invariants, composition, time, or approach trade-offs materially affect correctness. Do not load for routine local edits or turn its prompts into mandatory ceremony.
---

# Cognitive Primitives

Select only the lenses that expose a material risk or decision. Record the
answer, not a ritual list of primitive names.

## State And Invariants

- Identify relevant valid, invalid, transitional, and terminal states.
- State the preconditions, postconditions, and stable or temporal invariants that
  matter to the requested behavior.
- Enforce invariants at the strongest practical boundary: types, schemas,
  constraints, authorization, transactions, runtime checks, or tests.
- Do not force every edge case into the type system when external data, legacy
  contracts, or runtime policy make boundary validation clearer.

## Boundaries And Time

- Identify trust, process, module, persistence, network, and concurrency
  boundaries that the change actually crosses.
- Define data shape, ownership, error semantics, limits, timeout behavior, and
  recovery where relevant.
- Model ordering, retries, duplicates, cancellation, partial completion, clock
  assumptions, and race windows only when the system can exhibit them.

## Composition And Approach

- Prefer cohesive pieces with explicit inputs, outputs, and ownership.
- Reuse a local abstraction when it fits; keep one-off logic local when
  extraction would add indirection.
- Compare viable approaches by correctness, security, operational cost,
  performance, reversibility, maintainability, and codebase fit.
- Separate complexity inherent in the problem from complexity introduced by the
  solution, then remove or isolate the latter.

## Evidence

Treat these lenses as ways to form requirements and hypotheses, not as proof.
Implementation is never proof of correctness. Match important claims with
proportional evidence from tests, static checks, runtime observation, contracts,
benchmarks, or formal analysis.

## Hard Rules

- Do not apply every lens to every task.
- Do not justify a pattern by name alone.
- Do not convert an unverified mental model into a verified claim.
