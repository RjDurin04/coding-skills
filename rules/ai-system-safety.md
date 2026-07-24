---
name: ai-system-safety
trigger: model_decision
description: Apply when product behavior uses models, embeddings, retrieval, agents, or tool calls. Covers prompt injection, authorization, output validation, evaluations, drift, privacy, reliability, and cost.
---

# AI System Safety

This gate applies to software whose runtime behavior depends on AI/ML/LLM
systems. AI-assisted coding by itself uses `rules/ai-provenance-disclosure.md` and
does not trigger this gate.

## Trigger

Model or embedding APIs, retrieval/vector search, generated user-visible or
decision-making content, agents, tool/function calls, model-written queries/code,
autonomous workflows, fine-tuning, or model/provider/version changes.

## 1. Trust Boundaries And Data

- Classify system/developer instructions, user input, retrieved content, tool
  output, memory, and model output as separate trust domains.
- Treat user/retrieved/model content as untrusted. Prompt injection cannot grant
  permissions, reveal hidden instructions/secrets, or expand tool scope.
- Minimize data sent to providers. Verify retention, training use, residency,
  access, deletion, and logging terms for the data class involved.

## 2. Tool And Action Authorization

- Use least-privilege, allowlisted tools with typed inputs, validated targets,
  bounded arguments, timeouts, and cost/fan-out limits.
- Authorize every consequential action outside the model. The model may propose;
  deterministic policy and `rules/agent-operation-safety.md` decide whether it
  may execute.
- Require human review for high-impact legal, financial, medical, employment,
  safety, security, permission, destructive, or production actions unless an
  approved domain control explicitly provides equivalent oversight.

## 3. Output Contracts And Grounding

- Parse model output into a strict schema and reject malformed, extra, unsafe,
  or out-of-policy fields. Do not execute raw model-generated code, shell, SQL,
  URLs, or templates without a purpose-built validator/sandbox and authorization.
- When factual accuracy matters, define acceptable sources, citations/grounding,
  freshness, abstention, and uncertainty behavior. Never represent generated
  confidence as calibrated evidence without measurement.
- Escape/encode generated content for its destination to prevent injection and
  unsafe rendering.

## 4. Evaluations And Change Control

- Maintain representative, adversarial, privacy, safety, and regression
  evaluation cases tied to user-visible acceptance evidence. Record dataset
  provenance, collection/labeling limits, holdout separation, leakage checks,
  important subgroup/edge behavior, human or non-AI baseline where useful, and
  uncertainty/abstention behavior.
- Use accepted evaluation thresholds. Label proposed thresholds `CANDIDATE`
  with an owner and validation plan; do not invent a number and call it a
  requirement or production gate.
- Evaluate prompt, model, provider, retrieval, tool, policy, and preprocessing
  changes before rollout. Pin or record versions where supported; detect silent
  provider/model drift.
- Test prompt injection, data exfiltration, privilege escalation, harmful tool
  calls, malformed output, hallucination/abstention, multilingual/edge inputs,
  latency, and cost as applicable.

## 5. Reliability, Scale, And Cost

- Define timeouts, retry limits, idempotency, fallback/degraded behavior, provider
  outage handling, and duplicate/out-of-order tool results.
- Bound tokens, context, retrieval results, tool loops, concurrency, and per-user/
  tenant/global spend. Rate-limit abuse and detect anomalous usage/cost.
- Do not assume deterministic output. Keep durable state transitions outside the
  model and make consequential operations replay-safe.

## 6. Observability And Review

- Measure task success, evaluation regressions, refusal/abstention, unsafe output,
  tool denial/failure, latency, token use, and cost without logging sensitive
  prompts or full payloads by default.
- Provide user-visible disclosure and correction/escalation paths appropriate to
  the product and risk. Preserve audit evidence for consequential actions.
- Define drift detection, rollback/kill switch, evaluation owner, and evidence
  review cadence for material behavior.

## Delivery Contribution

Add material AI boundaries, evaluations, tool controls, version/provider
assumptions, unverified safety/cost/privacy gaps, and required human oversight to
the unified delivery record in `GEMINI.md`.

## Release Blockers

Block release when consequential tools lack deterministic authorization, model
output is executed without validation, sensitive data use is unauthorized,
material acceptance/safety evaluations fail or do not exist, or cost/fan-out is
unbounded.

