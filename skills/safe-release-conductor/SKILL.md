---
name: safe-release-conductor
description: Use when preparing to deploy code to any shared environment (staging, production). Activates on deploy scripts, CI/CD config, release PRs, or when user says "let's ship", "deploy to prod", or "push this live". Produces a progressive-delivery plan with rollback triggers, observability hooks, and blast-radius controls BEFORE the deploy happens.
---

# Safe Release Conductor

## Activation Procedure

Before deploying, ask:
1. Did the user say "deploy", "ship", "push to prod", "release", or "go live"?
2. Am I generating deployment scripts, CI/CD config, or infrastructure code?
3. Am I about to mutate a shared environment or execute a release action?

If ≥1 is YES → engage for the release-related portion. Merely editing code that
may eventually run in production does not trigger deployment procedure. Local-only
changes (unit tests, lint config) do not trigger.

## Execution Protocol

### Step 1: Pre-Flight Checklist
All applicable boxes require evidence. Mark a box N/A with a reason; an unchecked
applicable box blocks the release claim.
```
[ ] Required CI checks pass, or the unavailable CI evidence is a blocker
[ ] Migrations are compatible and recoverable when schema/data changes exist
[ ] Risky behavior has an appropriate blast-radius control (flag, canary, staged rollout, or equivalent)
[ ] Rollback or roll-forward procedure is documented and tested proportionally
[ ] Applicable logs, metrics, traces, health checks, and alerts are in place
[ ] Runbook and escalation owner cover likely failure modes
[ ] Blast radius identified
[ ] Deploy timing and staffing fit the service's traffic and support model
[ ] Config, secrets, state, and environment parity fit the system's architecture
[ ] Human authority for the shared-environment mutation is verified
```

### Step 2: Delivery Strategy
| Risk Level | Strategy |
|---|---|
| Config/copy | Direct or staged deploy with a rollback plan; flag only when useful |
| Non-critical | Progressive rollout sized to traffic, observability, and rollback speed |
| Critical path | Canary, blue/green, shadowing, or equivalent evidence-based isolation |
| Schema change | Expand-contract over releases |
| Irreversible | Dry-run in staging with prod-shaped data |

### Step 3: Rollback Triggers
Declare abort conditions before deploy:
```yaml
rollback_if:
  - error budget burns faster than the service threshold
  - latency exceeds the declared SLO or approved baseline envelope
  - a critical business/security invariant fails
  - saturation, queue depth, or cost exceeds the declared limit
```

### Step 4: Post-Deploy Verification
Do not claim success until applicable synthetic/end-to-end checks pass, key
business and reliability signals are within their declared envelopes, and the
predeclared observation window completes. When real traffic inspection is not
available, say so and keep the release status partial.

### Step 5: Handoff
Generate handoff note: DEPLOYED [what, version, time], WATCH FOR [symptoms], ROLLBACK CMD [exact command], ESCALATION [who].

## Hard Rule
Keep MTTR much smaller than MTBF. Optimize for prevention plus fast, safe
recovery; rollback speed does not excuse weak pre-deploy evidence.
