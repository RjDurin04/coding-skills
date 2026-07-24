---
name: ai-system-and-evaluation-engineer
description: Use when designing, implementing, reviewing, or evaluating AI, LLM, embedding, retrieval, classifier, ranking, generative, or tool-using agent behavior. Define measurable system contracts, representative evaluations, safety and authority controls, abstention and fallback, versioned evidence, rollout limits, and drift monitoring.
---

# AI System And Evaluation Engineer

Evaluate the end-to-end product behavior, not only a model response or vendor
benchmark.

## 1. Define The System Contract

Identify:

- user and decision being supported;
- inputs, context sources, outputs, consumers, and side effects;
- deterministic code, model behavior, retrieval, tools, and human steps;
- acceptable, abstained, escalated, and harmful outcomes;
- consequence and reversibility of a wrong decision;
- autonomy, approval, latency, cost, and data-handling limits;
- current human, rule-based, or model baseline.

Keep authorization, tenant scope, validation, and irreversible-action approval
outside probabilistic model judgment.

## 2. Build Trustworthy Evaluation Data

Document dataset provenance, permitted use, privacy classification, labeling
instructions, reviewer agreement, sampling frame, exclusions, and version.
Separate development and holdout sets. Check training or prompt leakage,
duplicate examples, benchmark contamination, temporal leakage, and feedback-loop
bias.

Include representative languages, formats, difficulty, user groups, edge cases,
and high-consequence slices. Do not use live sensitive data or send it to a
provider without the required purpose, contract, configuration, and authority.

## 3. Match Metrics To Failure Cost

Select metrics and rubrics that can distinguish the decision:

- classification/ranking: confusion by class, precision/recall, calibration,
  coverage, and abstention;
- retrieval: authorized recall, precision, freshness, grounding, and citation
  correctness;
- generation: task rubric, factual support, completeness, consistency, and
  human preference where appropriate;
- agents/tools: policy compliance, correct tool and arguments, approval
  enforcement, duplicate side effects, prompt injection, indirect injection,
  data exfiltration, and recovery;
- operations: end-to-end latency, throughput, availability, token or provider
  cost, and fallback rate.

Treat proposed thresholds as candidates until approved. Compare against a
relevant baseline, run enough repeated trials to expose stochastic variation,
and report sample size and uncertainty. A model grading itself is one signal,
not independent proof.

## 4. Engineer Runtime Safeguards

- Treat prompts, retrieved content, tool output, and model output as untrusted.
- Enforce schemas, ranges, permissions, tenant filters, and business invariants
  in deterministic code.
- Give tools least privilege; bind actions to the authenticated user and require
  approval at the actual side-effect boundary. Approval may be per action or a
  deterministic owner-approved automation policy with explicit scope,
  eligibility, limits, auditability, recourse, and revocation. Model confidence
  alone is never that policy.
- Bound context, output, retries, concurrency, time, tokens, fan-out, and cost.
- Provide abstention, recourse, human review, timeout, fallback, and kill-switch
  behavior appropriate to consequence.
- Pin or record model, provider, prompt, retrieval index, tool schema, policy,
  and evaluation-set versions.
- Minimize and redact logs; never place secrets in model context.

## 5. Release And Monitor

Use offline evaluation before authorized shadow, canary, experiment, or live
rollout. Prevent online experiments from silently changing user rights,
high-impact decisions, or irreversible actions. Monitor quality slices, safety
violations, abstention, overrides, latency, cost, data drift, model drift, and
feedback-loop effects with predeclared stop criteria.

Bind every claim to the exact system version, dataset, environment, date, and
coverage. A demo, a few examples, or a provider benchmark does not establish
production behavior.

## Hard Rules

- Do not force a prediction when abstention is safer.
- Do not treat model confidence as calibrated probability without evidence.
- Do not claim an AI system safe, fair, accurate, or production-ready beyond the
  evaluated population and failure modes.
