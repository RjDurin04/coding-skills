---
name: formal-assurance-engineer
description: Specify and verify critical software properties using contracts, types, property/state-machine testing, model checking, static analysis, proof, or other formal methods. Use for high-impact authorization, payments, safety, distributed protocols, concurrency, irreversible workflows, cryptographic protocol use, or algorithms whose invariants/liveness cannot be trusted through examples alone. Do not impose formal methods on ordinary low-risk code.
---

# Formal Assurance Engineer

Choose the lightest assurance technique that can credibly establish the required
property. A proof is only as strong as its model, assumptions, and connection to
the implementation.

## 1. Define The Assurance Claim

State the asset/outcome, failure consequence, system boundary, adversary/fault
model, property, and required confidence. Distinguish:

- Safety: something bad never happens.
- Liveness: something good eventually happens under stated fairness assumptions.
- Integrity/confidentiality/authentication properties.
- Functional, temporal, numerical, resource, or probabilistic properties.

List assumptions about inputs, clocks, arithmetic, runtime, compiler, storage,
network, dependencies, operators, and cryptography. Unknown assumptions weaken
the claim; do not hide them.

## 2. Build A Minimal Model

Define variables, types/domains, initial states, transitions, guards, invariants,
terminal states, error states, and environment actions. Bound the model only with
justification and state what remains outside it.

Model the dangerous concurrency, replay, ordering, permission, or failure behavior
rather than reproducing all implementation detail. Make illegal states explicit.

## 3. Select The Assurance Technique

Escalate only as needed:

1. Strong types, total functions, contracts, database constraints, and assertions.
2. Property-based, fuzz, metamorphic, differential, and state-machine tests.
3. Static analyzers, symbolic execution, abstract interpretation, or protocol/model checking.
4. Machine-checked proof or verified implementation for the highest consequence
   and stable specification.

Compare tool soundness/completeness limits, supported language/model, state-space
growth, solver assumptions, maintainability, and team ability to rerun it.

## 4. Falsify Before Trusting

Search for counterexamples: invalid initial state, boundary value, overflow/
precision, concurrent transition, stale authorization, replay, crash between
steps, unfair scheduling, time rollback, partition, malicious input, and model/
code mismatch. Preserve minimal counterexamples as regression artifacts.

Run the selected tool/check when available. Record exact model, bounds, versions,
result, warnings, timeouts, and unproven obligations. A timeout or bounded pass is
not a general proof.

## 5. Connect Model, Code, And Operations

Map each property to enforcing types/constraints/code, tests, static/model checks,
and runtime detection. Prevent drift with generated artifacts, shared definitions,
CI checks, refinement mapping, or focused review. Re-run assurance when the model,
implementation, compiler/runtime, dependency, or threat/fault assumptions change.

Define what operators should observe when an invariant is threatened and the
safe response.

## Delivery Contribution

Add the exact assurance claim, model boundary/assumptions, technique and tool
evidence, counterexamples, implementation mapping, and unproven obligations to
the unified delivery record in `GEMINI.md`.

## Hard Rules

- Never claim more than the model, bounds, tool, and assumptions establish.
- No formalism for prestige; assurance cost must match consequence and longevity.
- Examples alone do not establish a universal property.
- A model disconnected from implementation and change control is documentation,
  not durable assurance.

