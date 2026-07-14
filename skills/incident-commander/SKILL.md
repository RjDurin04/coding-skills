---
name: incident-commander
description: Coordinate active production or shared-environment incidents with user, security, data, availability, or major business impact. Use for incident severity, containment, roles, workstreams, status communication, recovery criteria, escalation, timeline, handoff, postmortem, and corrective-action ownership. Pair with observability-detective for technical diagnosis; do not activate for an ordinary local bug.
---

# Incident Commander

Protect users and restore safe service through disciplined coordination. Keep
command, technical diagnosis, communications, and decision authority explicit.

## 1. Establish Control

Record incident start/detection time, current time source/timezone, affected user
outcome, scope, severity, evidence, and unknowns. Assign or identify:

- Incident commander and decision authority.
- Technical/operations lead and workstream owners.
- Communications/support/security/privacy/legal owners when applicable.
- Shared channel, timeline/scribe, update cadence, and escalation path.

If humans already run the incident, support their structure; do not claim command
authority. Mark facts, inferences, hypotheses, and decisions separately.

## 2. Contain Harm

Prioritize safety, data/security containment, and blast-radius reduction before
complete root-cause certainty. Compare reversible options: disable/flag, isolate,
rate-limit, fail over, roll back/forward, revoke, drain, or degrade.

For each action state target, expected effect, risk, owner, validation, abort, and
recovery. Apply `rules/agent-operation-safety.md`; never infer permission to
mutate production, credentials, data, or customer communications.

Preserve logs, traces, audit evidence, artifacts, and timestamps needed for
diagnosis or legal/security review without exposing sensitive data.

## 3. Drive Evidence-Led Workstreams

Use `observability-detective` to maintain falsifiable hypotheses. Bound parallel
workstreams, assign owners, and stop duplicate or speculative changes. Maintain:

```
Time | Fact/Signal | Decision/Action | Owner | Result | Next check
```

Send concise updates: impact, current mitigation, confirmed facts, key unknowns,
next decision/check, and next update time. Do not publish an ETA without evidence.

## 4. Verify Recovery

Define recovery before declaring it:

- Critical synthetic/user journey succeeds.
- Error, latency, saturation, queue, security, data, and business signals return
  to declared envelopes.
- No continuing corrupting/leaking/duplicating effect.
- Backlog/reconciliation/compensation is understood and owned.
- Observation window covers the relevant traffic/job cycle.

Keep incident status partial while material signals or affected populations are
unknown. Handoff explicit watch conditions and rollback/escalation actions.

## 5. Learn Without Blame

After stabilization, build a fact-based timeline and explain contributing system
conditions, detection/response gaps, and why controls did not prevent or limit
impact. Avoid a single-person root cause.

Create corrective actions with risk addressed, owner, priority, due/review
condition, verification, and closure evidence. Update regression tests,
observability, runbooks, architecture decisions, and `failure-mode-catalog`.

## Delivery Contribution

Add incident status, impact, authority/roles, containment/recovery evidence,
remaining affected work, next owner, and required approval to the unified
delivery record in `GEMINI.md`.

## Hard Rules

- Stabilize and contain before optimizing the explanation.
- No production mutation or public/customer communication without authority.
- No recovery claim from one green metric or a quiet dashboard.
- No blameless postmortem without owned, verified follow-through.

