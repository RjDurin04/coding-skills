---
name: cognitive-primitives
description: Always-on foundational reasoning layer for any coding task. Activates during design, implementation, debugging, and review. Provides the mental models that transform mechanical coding into structural mastery — how to see state spaces, boundaries, invariants, composition, and time in any system.
---

# Cognitive Primitives

Always on. Explicitly invoke when designing interfaces, mutating state, debugging, or choosing between alternatives. If you reach for a pattern without naming the force it resolves — engage this skill first.

## Primitive 1: State Space Thinking
**Core question:** What states are possible? Which are valid? Can I make illegal states unrepresentable?
1. Enumerate all field/flag combinations; classify valid / invalid / unreachable.
2. Collapse the invalid region via types (sealed classes, exhaustive matching, constructor validation).
3. Prefer total functions — push edge cases to the type system, not runtime checks.

## Primitive 2: Boundary Thinking
**Core question:** Where are the system edges? What crosses them? What's the protocol? What's the failure mode?
1. Identify boundaries (I/O, network, process, module, thread, trust).
2. Define contract at each boundary: data shape, preconditions, postconditions, error encoding, backpressure.
3. Parse, don't validate — transform untrusted input into a rich type at the perimeter. Never pass raw across legacy/external boundaries.
4. Design failure mode per boundary (timeout, retry, circuit break, degrade, crash). Never silent swallow.

## Primitive 3: Invariant Thinking
**Core question:** What MUST be true before / after / during? How do I enforce it?
1. Preconditions — what must hold for this operation to be valid?
2. Postconditions — what must hold when this operation completes?
3. Invariants — what must hold at all stable states?
4. Temporal invariants — what ordering guarantees must hold?
5. Enforcement hierarchy: type system > runtime asserts / constraints > property-based tests > documentation.

## Primitive 4: Composition Thinking
**Core question:** Can I build this from smaller, testable pieces? Do the pieces compose without hidden coupling?
1. Decompose by responsibility; check that outputs of A are valid inputs for B with no shared mutable state.
2. Prefer pure functions. Minimize coupling surface.
3. Composition over inheritance. Abstraction resistance — when in doubt, inline; extract only when clearly simpler. Rule of Three before abstracting.
4. Cognitive load budget — keep scope within working memory (~7±2 concepts).

## Primitive 5: Temporal Thinking
**Core question:** What happens over time? What if events reorder? What if time moves backward?
1. Model the timeline; identify race windows where interleaving causes invalid states.
2. Consider replay / idempotency — can this operation run twice safely?
3. For complex flows, explicitly define states, transitions, and guards (state machine).
4. Distributed: enforce happens-before, use logical clocks not wall-clock, design for at-least-once delivery.

## Primitive 6: Formal Contract Thinking
**Core question:** What is the mathematical/specification essence of this component?
1. Specify preconditions, postconditions, invariants algebraically (Design by Contract).
2. Before implementing, write the properties this code must satisfy; implementation is the proof.
3. Verify associativity, commutativity, identity where applicable. Preserve contract through refinement steps.

## Primitive 7: Approach Selection Thinking
**Core question:** Why this approach instead of the obvious weaker one?
1. Compare reuse, smallest direct change, and structural change before standard+ implementation.
2. For algorithms, compare dominant operations, input growth, time/space complexity, I/O shape, and memory bounds.
3. Reject options by named force: correctness, security, performance, maintainability, reversibility, local convention, or complexity.
4. If the fastest patch leaves a broken model, name the refactor or architecture decision instead of hiding it.

## Essential vs. Accidental Complexity
Before committing: classify complexity as essential (inherent to the problem) or accidental (introduced by our solution). Remove or isolate accidental complexity; never let it leak into the domain model.

## Hard Rule
Every non-trivial design decision must be traceable to at least one Cognitive Primitive. If you cannot name the primitive that justifies a structure, the justification is intuition — and intuition is a bug when stakes are high.
