---
name: engineering-leadership
description: Lead multi-person or cross-team technical work. Use for prioritization, technical roadmaps, delegation, code/design reviews, mentoring, stakeholder alignment, decision rights, disagreements, ownership, handoffs, maintenance planning, or balancing delivery with engineering risk. Do not use to add management ceremony to a small solo implementation.
---

# Engineering Leadership

Create clarity, ownership, and learning while protecting users and technical
integrity. Leadership changes the decision system; it is not senior-sounding prose.

## 1. Frame The Decision And People System

Identify desired outcome, users, business/technical constraints, stakeholders,
owners, approvers, contributors, consulted experts, and people affected by the
change. State which decisions are reversible, delegated, or require escalation.

Surface incentives, operational burden, support impact, dependencies, and
unspoken constraints. Mark assumptions; do not manufacture consensus or authority.

## 2. Prioritize And Sequence

Compare work by user/business value, risk reduction, urgency, dependency,
reversibility, opportunity cost, and maintenance load. Include do-less, defer,
retire, and buy/reuse options. Separate critical-path work from parallelizable
work and define integration checkpoints.

Protect time for tests, observability, documentation, migration, support, and
debt only where they reduce a named risk. Make accepted debt explicit with owner
and exit condition.

## 3. Delegate With Context And Boundaries

Delegate outcomes, authority, constraints, interfaces, evidence, and check-in
conditions—not keystrokes. Match work to capability while preserving learning
and review. State:

```
Outcome | Owner | Scope/authority | Interfaces | Evidence | Escalate when
```

Do not delegate accountability invisibly. Avoid splitting tightly coupled work
only to maximize parallel activity.

## 4. Review For The Right Things

Review requirement fit, contracts, security/data impact, failure modes,
operability, simplicity, tests, and maintainability before style. Distinguish:

- Blocker: correctness, safety, contract, or material long-term risk.
- Suggestion: reasonable improvement without blocking evidence.
- Question: missing context or teaching opportunity.

Give specific evidence and explain the protected outcome. Invite correction and
update the decision when new facts win. Praise reasoning and learning, not heroics.

## 5. Communicate And Resolve Disagreement

Adapt detail to executives, product, support, security, operators, and engineers
without changing facts. Present decision, options, evidence, consequences,
owner, and next review point. For disagreement, identify the disputed assumption
or value, choose the cheapest resolving evidence, and record the decision owner.

Escalate safety, ethics, compliance, harassment, security, or data-integrity
concerns through the appropriate human channel. Do not use delivery pressure to
silence material risk.

## 6. Ensure Durable Ownership

Define post-release owner, on-call/support path, documentation, dashboards,
maintenance budget, dependency upgrades, success review, and deprecation
conditions. Run retrospectives that change systems and follow through on actions.

## Delivery Contribution

Add the decision, prioritization, owners/authority, delegated outcomes, review
findings, unresolved disagreement, and follow-up conditions to the unified
delivery record in `GEMINI.md`.

## Hard Rules

- Authority does not override safety, security, privacy, data integrity, or facts.
- No fake consensus, invisible ownership, or delegation without decision bounds.
- Do not confuse urgency, seniority, or volume of output with priority.
- Leave the team and system easier to operate and change.

