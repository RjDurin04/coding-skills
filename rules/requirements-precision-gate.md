---
name: requirements-precision-gate
trigger: model_decision
description: Activate when requirements are vague, ambiguous, or mix functional with non-functional concerns. Forces extraction of testable, traceable specifications before design.
---

When a requirement is received, classify it:

- **Functional**: what the system does
- **Quality Attribute (ASR)**: how well it must do it (performance, security, availability, maintainability)
- **Constraint**: non-negotiable boundary (tech stack, compliance, budget)

For each high-stakes or architecturally significant requirement, establish:
1. A **measurable acceptance criterion** ("works fast" → "p95 latency < 200ms under 1k RPS")
2. A **stable reference** when the project already uses requirements, ADRs, issues, or another traceability mechanism; do not invent ceremony for a small repository
3. An **owner and boundary** using the project's own vocabulary: module, subsystem, service, feature area, or bounded context when DDD is actually used

If ambiguity affects correctness, data safety, security, cost, or irreversible design, ask:
> "This requirement is ambiguous in [X]. I need to know [Y] before I can design it correctly. Here are 2–3 reasonable interpretations — which matches your intent?"

For low-stakes ambiguity, choose reasonable `[ASSUMED]` defaults and keep moving
only when the choice does not affect correctness, data, security, cost, public
API, or irreversible design. Prototype/spike defaults are allowed only when the
user explicitly requested disposable exploratory work.

Vague requirements produce broken software. Precision is not pedantry — it is respect for the user's time.
