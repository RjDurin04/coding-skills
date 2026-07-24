---
name: requirements-crystallizer
description: Use when a material requirement is vague, unmeasurable, internally inconsistent, or missing acceptance conditions, especially for quality attributes, AI behavior, public contracts, security, data, cost, or costly-to-reverse design. Convert uncertainty into scoped decisions and testable acceptance evidence without inventing targets.
---

# Requirements Crystallizer

Clarify only ambiguity that can change correctness, safety, scope, cost, public
behavior, or a durable design. Keep routine low-risk choices lightweight.

## 1. Separate Requirement From Solution

Extract the user or business outcome, affected actors, in-scope and out-of-scope
behavior, constraints, failure behavior, and acceptance evidence. Do not turn a
preferred framework, pattern, or implementation idea into a requirement unless
it is an actual constraint.

## 2. Track Decision Status

Use these statuses for material requirement values:

- `[APPROVED]`: an authoritative source or explicit owner decision establishes
  the value;
- `[CANDIDATE]`: a proposed value to evaluate or approve;
- `[ASSUMED]`: a reversible low-risk default selected to continue;
- `[UNKNOWN]`: no defensible value is available.

Treat derived or proposed numeric targets as `[CANDIDATE]`, or `[UNKNOWN]` when
there is no basis, until an authorized owner or authoritative contract approves
them. Do not convert a benchmark, industry heuristic, or model suggestion into
an approved SLO, retention period, capacity target, accuracy threshold, or
deadline.

## 3. Create A Proportional Requirement Record

For an architecturally significant requirement, capture:

```text
ID/source: [...]
Outcome and scope: [...]
Decision status: APPROVED | CANDIDATE | ASSUMED | UNKNOWN
Acceptance evidence: [...]
Quality attributes and constraints: [...]
Failure and edge behavior: [...]
Open decision/owner: [...]
```

Use the project's existing issue, specification, ADR, or test mechanism when it
will remain maintained. A local note is enough for a small decision; do not
create traceability artifacts for their own sake.

## 4. Decide Whether To Proceed

Ask for a decision when the unknown changes security, privacy, data integrity,
material cost, public compatibility, user harm, or an expensive-to-reverse
design. Otherwise choose the smallest reversible assumption, label it, and
verify behavior against it.

## Hard Rules

- Do not manufacture specificity.
- Do not claim an acceptance criterion is approved merely because it is
  testable.
- Do not block unrelated safe work on an immaterial ambiguity.
