---
name: risk-radar-scout
description: Use during new project or significant feature inception to surface project-killing risks before implementation. Produces a ranked risk scan and smallest-valid experiment without over-blocking small work.
---

# Risk Radar Scout

Engage when at least two are true:

- The user is describing a new project, major feature, or materially new domain.
- Scope appears larger than a small local change.
- The work introduces external dependencies, money flow, sensitive data, compliance, AI automation, or production operations.
- No risk scan has been done for this project or the scope has materially changed.

Do not engage for ordinary bug fixes, small UI tweaks, straightforward tests, or
explicitly requested local disposable prototypes.

## Step 1: Extract Claims

Identify:

- Business claim: who uses/pays and why.
- Technical claim: what must be possible.
- Scale claim: users, requests, data, latency, cost.
- Timeline claim: when it must work.
- Trust claim: what data, permissions, or external systems are involved.

Mark unsupported claims as `[ASSUMED]`, `[INFERRED]`, or `[UNKNOWN]`.

## Step 2: Seven-Vector Risk Scan

For each relevant vector, record:

```
Risk | Likelihood H/M/L | Impact H/M/L | Detection | Mitigation | Kill criterion
```

Vectors:

- Regulatory/compliance.
- Technical feasibility.
- Economic/API/infrastructure cost.
- Dependency and supply chain.
- Adoption and workflow fit.
- Competitive or replacement pressure.
- Team, operational, and maintenance fit.

Skip irrelevant vectors for small work.

## Step 3: Smallest Valid Experiment

Recommend the cheapest experiment that could falsify the riskiest assumption:

- Prototype.
- Spike.
- Load test.
- Security review.
- User workflow test.
- Integration proof.
- Data migration dry run.

The experiment should be scoped in hours or days, not weeks, unless the project itself is critical.

## Step 4: Decide Whether To Block

Only block implementation when a blocker risk affects correctness, security, data safety, legal/compliance exposure, irreversible design, or major cost.

For non-blocking risks:

- Proceed with `[ASSUMED]` defaults.
- Record the watchlist.
- Add tests, flags, or scope limits that reduce blast radius.

## Output

```
Risk scan: PASS | WATCHLIST | BLOCKED
Blockers: [...]
Watchlist: [...]
Smallest valid experiment: [...]
Proceed recommendation: proceed | spike first | reshape scope | ask user
```

## Hard Rules

- Do not turn every new idea into a heavyweight planning ceremony.
- Do not start critical work with unexamined project-killing assumptions.
- A risk scan should reduce uncertainty or scope, not merely sound smart.
