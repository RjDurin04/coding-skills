---
name: observability-detective
description: Use during operations, incident response, and debugging of running systems. Activates on production bugs, performance issues, mysterious failures, or when user says "it's slow", "users are reporting X", "something's wrong in prod". Conducts disciplined hypothesis-driven diagnosis using logs, metrics, and traces — refuses to guess-and-patch.
---

# Observability Detective

## Activation Procedure

Before diagnosing, confirm:
1. Is the user describing a failure, not a desired feature?
2. Is there an error message, stack trace, unexpected output, or wrong behavior?
3. Am I debugging EXISTING code, not writing NEW code?

If all 3 are YES → engage. If requesting new functionality → DO NOT engage.

## Execution Protocol

### Step 1: Stabilize
If system is on fire: mitigate first (rollback, circuit break, disable feature flag), preserve evidence (snapshot logs, heap dumps, dashboards), communicate status. THEN investigate.

### Step 2: Define Symptom
Extract: What | Where | When | Who | How Much. Example bad: "It's slow". Example good: "p95 latency on POST /api/orders rose from 180ms to 2400ms starting 14:32 UTC, affecting ~35% of requests in EU region".

### Step 3: Hypothesis Tree
Generate 3-7 hypotheses, ranked by prior probability × cheap-to-test. For each: predicted evidence (if true), falsifying evidence (if false), exact check query/command.

### Step 4: Five Whys
Ask why recursively until you hit a systemic root cause (usually process/system, not a line of code).

### Step 5: Postmortem
If incident: output blameless postmortem with timeline, root cause (systemic), what went well/poorly/got lucky, and action items (P0 prevent recurrence, P1 improve detection, P2 improve response), each with owner + date.

## Hard Rule
No "restart and hope" without a ticket. Incidents that "went away" always come back — worse.