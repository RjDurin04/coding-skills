---
name: observability-detective
description: Use to diagnose symptoms in a running system, including errors, latency, throughput, saturation, stale or incorrect data, missing or duplicate work, cost anomalies, and security signals. Correlate telemetry with changes, propose containment, and check authority before executing any shared-system mutation.
---

# Observability Detective

## 1. Define The Symptom

Record the affected behavior, population, region or tenant, endpoint or worker,
start and end times, frequency, magnitude, baseline, and business consequence.
Use synchronized time ranges and preserve exact query parameters or dashboard
filters needed to reproduce the view.

If impact is active, propose bounded containment and evidence preservation. Use
the incident skill for coordination when warranted. Do not roll back, restart,
disable, scale, purge, or change a shared system unless the requested task and
required authorization allow it.

## 2. Check Telemetry Quality

Assess missing spans, sampling, aggregation, cardinality, clock skew, retention,
scrubbing, delayed ingestion, and inconsistent identifiers before trusting a
signal. Avoid queries that expose secrets or personal data.

Triangulate relevant evidence across:

- user-visible and business outcomes;
- rates, errors, duration, throughput, saturation, queues, and cost;
- logs, traces, events, audit records, and data-store state;
- deploys, feature flags, configuration, dependencies, traffic, and capacity.

## 3. Test Hypotheses

Rank plausible causes by consequence, prior evidence, and cost or risk of the
next check. For each, state the expected signal, disconfirming signal, and exact
read-only query or controlled experiment. Look for the earliest divergence and
distinguish correlation from causation.

Use `[VERIFIED] cause`, `[INFERRED] cause`, or `[UNKNOWN] cause` to calibrate the
result. A disappearing symptom is not proof of resolution; define the
observation that would detect recurrence.

## 4. Close The Diagnostic Loop

Report:

- symptom scope and timeline;
- evidence and causal confidence;
- proposed containment and permanent correction;
- telemetry gaps and the smallest useful instrumentation change;
- remaining risks and observation plan.

Create a postmortem, Five Whys analysis, ticket, or owned follow-up only when the
incident process or user request calls for it. Do not invent owners or dates.

## Hard Rules

- Do not restart and infer a root cause from symptom disappearance.
- Do not execute containment merely because it is technically available.
- Do not call a dashboard green when the user-visible invariant remains
  unverified.
