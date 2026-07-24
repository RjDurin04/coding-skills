---
name: risk-radar-scout
description: Use at the inception or material reshaping of a project or major feature when feasibility, adoption, dependency, cost, compliance, sensitive-data, AI, or operational assumptions could change the decision. Rank uncertainty with a defined scoring method and propose the smallest decision-relevant experiment.
---

# Risk Radar Scout

Do not use for routine bug fixes, small local changes, or a narrowly scoped
disposable prototype unless a material external or safety risk remains.

## 1. Extract Decision-Critical Claims

Capture the business, workflow, technical feasibility, scale, cost, timeline,
trust, dependency, and operational claims that could invalidate the plan. Mark
the evidence and confidence for each; omit dimensions that cannot affect the
decision.

## 2. Score Consistently

Score inherent risk before proposed controls and residual risk after them.

```text
Likelihood:
1 = rare under stated conditions
3 = plausible or seen in comparable conditions
5 = expected, recurring, or already observed

Impact:
1 = local and readily reversible
3 = material user, operational, or financial harm with a recovery path
5 = severe or irreversible safety, legal, security, privacy, data, or business harm

Priority score = Likelihood x Impact
1-4 low | 5-9 moderate | 10-16 high | 17-25 critical
```

Use 2 or 4 only when evidence falls between anchors. Add `confidence:
high|medium|low`; a low-confidence score is a discovery signal, not false
precision. The score prioritizes investigation and mitigation but never lowers a
governance risk floor or grants authority.

For each high or critical item, state:

```text
Risk/cause/consequence: [...]
Evidence and confidence: [...]
Inherent L/I/score: [...]
Control and owner: [...]
Residual L/I/score: [...]
Detection and kill criterion: [...]
```

## 3. Choose The Smallest Valid Experiment

Select the least costly safe experiment that could change the decision:
prototype, integration proof, user workflow study, threat review, load test,
cost model, data-quality sample, or migration dry run. Size it by the evidence
needed, decision deadline, safety, and expected information gain, not by an
arbitrary number of hours or days.

## 4. Recommend Action

Block only when a credible unresolved risk prevents correct, lawful, safe, or
economically authorized progress, or would lock in an irreversible design.
Otherwise recommend proceeding with explicit limits, controls, and a watchlist.

## Hard Rules

- Do not use scoring to disguise missing evidence.
- Do not enumerate risks that cannot affect the decision.
- A risk scan must change scope, evidence, controls, or the decision.
