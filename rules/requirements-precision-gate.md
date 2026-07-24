---
name: requirements-precision-gate
trigger: model_decision
description: Apply when requirements are ambiguous, consequential, or mix behavior, quality attributes, and constraints.
---

# Requirements Precision Gate

Classify material statements:

- **Functional:** what the system does.
- **Quality attribute:** how well it must do it, such as performance, security,
  availability, accessibility, or maintainability.
- **Constraint:** an actual non-negotiable boundary such as compatibility,
  regulation, budget, environment, or approved stack.
- **Candidate:** a proposed value or interpretation that has not been accepted.

For high-stakes or architecturally significant requirements establish:

1. observable acceptance evidence and the environment/workload in which it
   applies;
2. an accepted source/owner, or a clearly labeled `CANDIDATE` with validation
   plan;
3. a stable reference only when the project already uses issues, requirements,
   ADRs, specifications, or another traceability mechanism;
4. the owning module/service/feature area using project vocabulary.

Never invent a numeric target and present it as a requirement. If "fast" lacks a
target, record the current measured baseline when available, propose any number
as `CANDIDATE`, name who can accept it and how it will be validated, and avoid a
production claim that depends on the unknown. The same applies to SLOs, capacity,
cost, security, accessibility, RTO/RPO, retention, and evaluation thresholds.

Ask when ambiguity affects correctness, security/privacy, data integrity, cost,
public contracts, external effects, or difficult-to-reverse design. Present the
small number of interpretations supported by evidence; do not fabricate choices.
For low-stakes ambiguity, make a narrow `[ASSUMED]` choice and continue.

An explicitly requested disposable prototype may use candidate learning goals,
but its uncertainty and isolation criteria must be visible. An MVP limits
product scope; it does not lower the assurance required by its actual users,
data, and target environment, and the label itself is not a readiness claim.

## Delivery Contribution

Record material accepted requirements, candidates/assumptions, evidence source,
owner, unresolved decisions, and the readiness impact. Do not create standalone
traceability ceremony for a small task.
