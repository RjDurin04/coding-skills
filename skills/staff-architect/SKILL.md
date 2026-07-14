---
name: staff-architect
description: Use for structural decisions, long-lived boundaries, repo layout, risky dependencies, data architecture, or changes that are costly to reverse. Forces trade-off analysis before design commitment.
---

# Staff Architect

Engage when:

- Failure affects users, money, data, security, availability, or compliance.
- Reversal cost is high.
- A new dependency, framework, service, database, queue, cache, or infrastructure component is proposed.
- Public APIs, module boundaries, schemas, or ownership models change.
- You are scaffolding a new durable capability.

## Step 1: Define The Decision

State:

- Decision to make.
- Requirements and quality attributes driving it.
- Constraints from the existing codebase.
- Options considered, including "do less" and "reuse existing pattern."
- Weaker options rejected, including shortcut/MVP paths, and the concrete reason they fail.
- Reversibility: Type 0 trivial, Type 1 expensive/irreversible, Type 2 reversible.

## Step 2: Pre-Mortem

Write concrete failure stories:

```
Thirty days after release, this failed because [...]
Users/operators noticed [...]
The data/security/operational consequence was [...]
We would detect it by [...]
We would mitigate it by [...]
```

Create a small risk register:

```
Risk | Likelihood | Impact | Detection | Mitigation | Owner
```

Redesign or reduce scope for blockers. Warnings need mitigation or explicit acceptance.

## Step 3: Fit The Local Architecture

Respect the project's existing architecture before introducing a new one.

Check:

- Ownership and bounded context.
- Dependency direction.
- Public interface shape.
- Persistence and transaction boundaries.
- Operational ownership.
- Testing and observability seams.

Use modular monolith, DDD, ports/adapters, eventing, microservices, or other patterns only when the local system and problem justify them.

## Step 4: Decision Record

Record durable decisions.

Mini-ADR:

```
ADR-NNN: [title]
Status: Proposed | Accepted | Superseded
Context: [...]
Decision: Choose [X] over [Y, Z]
Why: [...]
Consequences: [...]
Reversal plan: [...]
```

Use a full ADR plus prototype for Type 1 decisions. Type 2 decisions can use a mini-ADR. Type 0 decisions do not need an ADR.

## Output

```
Architecture review: PASS | PARTIAL | BLOCKED
Decision: [...]
Options considered: [...]
Risks/mitigations: [...]
ADR needed: YES | NO
Risk: BLOCKER | WARNING | NOTE - [...]
```

## Hard Rules

- Do not impose architecture that the project does not need.
- Do not make expensive decisions without naming alternatives and reversal cost.
- Do not let a prototype shortcut become durable architecture without explicit redesign.
- Code that violates an accepted ADR or boundary is a bug unless the decision is explicitly revised.
