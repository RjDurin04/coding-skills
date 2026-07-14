---
name: observability-by-design
trigger: model_decision
description: Proportional observability for services, handlers, jobs, integrations, critical UI flows, and production-facing code.
---

# Observability By Design

Goal: maintainer can answer "working?", "affected?", "changed?", "why failed?",
and "what next?" without noisy or unsafe instrumentation.

## Trigger

API/controller/service/job/worker/scheduler/queue/webhook/import/export/
integration; auth, payments, data mutation, notifications, AI/tool calls, file
processing, external deps; production behavior whose failure is hard to diagnose.
Skip trivial pure functions, local-only scripts, static copy, and UI-only changes
with no hidden runtime workflow.

## Tier

| Tier | Use when | Signals |
|---|---|---|
| Minimal | local/trivial/self-evident | existing errors/tests |
| Standard | normal runtime/user flow/external call/background work | structured boundary logs + contextual errors |
| Critical | money/auth/PII/data integrity/high volume/prod incident risk | logs, metrics, traces/correlation, alerts/health/runbook as applicable |

## Instrument Boundaries

Prefer request/job start-finish; external call result/latency/timeout/retry
exhaustion; state transition/irreversible decision; safe validation/authz denial;
batch progress/summary; unexpected error with correlation/request/job ID.
Avoid tight-loop logs, full payloads, and messages nobody can act on.

## Signals To Consider

Logs (structured, searchable, safe context), metrics (count, latency, error rate,
saturation, queue depth, retries, invariant), traces (multi-step/cross-service
causality), health/readiness (serving ability), alerts (actionable owner/threshold),
runbook note (human action needed).

## Safety

Never log secrets, tokens, credentials, raw PII, payment data, full prompts, or
full payloads. Redact/hash identifiers when full values are unnecessary. User
errors should help without leaking internals. Debug logs must not become prod leaks.

## Delivery Contribution

Add only material signals, maintainer questions now answerable, missing
detection, and resulting risk to the unified delivery record in `GEMINI.md`.

## Hard Rules

- Invisible/expensive failure needs a signal.
- Non-actionable signal should be removed/reduced.
- Sensitive-data leakage in observability is a bug.
