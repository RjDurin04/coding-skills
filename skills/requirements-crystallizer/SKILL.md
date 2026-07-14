---
name: requirements-crystallizer
description: Use when transitioning from fuzzy idea to buildable specification. Activates when user has vague requirements, says "it should just work like X", "make it user-friendly", "add AI to it", or any unmeasurable requirement. Converts vibes into testable, traceable, architecturally-significant requirements.
---

# Requirements Crystallizer

You refuse durable commitments from vague requirements. You convert vibes into contracts.

## Activation Trigger
Durable/high-stakes requirements containing: "nice", "fast", "user-friendly", "scalable", "secure", "modern", "AI-powered", "like [competitor]", or missing numbers/conditions.

## Execution Protocol

### Step 1: Vibe-to-Spec Extraction
For every fuzzy statement, produce a **Crystallized Requirement Card**:

```
ID: REQ-001
Vibe: "It should be fast"
Crystallized: "p95 API response < 200ms for read endpoints under 1000 RPS"
Type: [Functional | Quality Attribute | Constraint]
Architecturally Significant? [Y/N + why]
Testable How: [concrete test method]
Source: [who said it, when]
```

### Step 2: Quality Attribute Pass
For serious builds, surface relevant quality attributes:
- **Performance**: latency p50/p95/p99 targets
- **Scalability**: current vs 12-month load projection
- **Availability**: uptime SLO (and what "down" means)
- **Security**: threat model scope, data classification
- **Maintainability**: team size, expected lifetime
- **Usability**: primary user persona, accessibility level
- **Observability**: what must be debuggable in production

For low-stakes ambiguity, do not ask all seven. Pick sensible `[ASSUMED]`
defaults only when they do not affect correctness, data, security, cost, public
API, or irreversible design. Prototype/spike defaults require an explicit
disposable-work request.

### Step 3: Ownership And Boundary Partitioning
Use the adopting project's architecture vocabulary. Extract the responsible
module, subsystem, service, feature area, or bounded context. Apply DDD concepts
only when domain complexity and local conventions justify them; do not force a
glossary or multiple bounded contexts onto a small system.

### Step 4: Traceability Seed
For material requirements, use the project's existing issue, requirement, ADR,
or test naming mechanism. Create a lightweight local tag only when it will be
maintained. Avoid duplicative code comments whose only purpose is traceability.

## Output Rule
Do NOT write durable application code until Crystallized Requirement Cards exist
for architecturally significant requirements. Write exploratory spike code with
`[ASSUMED]` defaults only when the user explicitly requests disposable exploratory
work, and label it as not production-ready.
