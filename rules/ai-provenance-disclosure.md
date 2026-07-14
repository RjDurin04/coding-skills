---
name: ai-provenance-disclosure
trigger: model_decision
description: Apply to non-trivial AI-assisted code, design, test, docs, dependency, or release changes. Record what was generated, verified, and left uncertain.
---

Trust requires provenance: what changed, why, by whom, and how it was checked.

## Trigger

Use for non-trivial AI-assisted work: multi-file changes, architecture/security/data/dependency/UI/release impact, PRs, releases, reusable docs, or customer-facing output.

## Disclose

- **Intent:** User ask in plain language.
- **Scope:** Files created/modified/reviewed.
- **Context used:** Important files, docs, ADRs, tests, APIs, or external references consulted.
- **Assumptions:** Material `[ASSUMED]`, `[INFERRED]`, unknowns, or unresolved choices.
- **Human review points:** What a person should inspect.
- **Checks run:** Tests, lint, typecheck, build, scans, browser/manual checks, or none.
- **Not verified:** Important gaps.
- **Residual risk:** BLOCKER/WARNING/NOTE.

## IP/Source Hygiene

Do not paste/derive substantial code from unknown copyrighted sources. Do not claim copyright, license, regulatory, or compliance safety without review. Do not store prompts containing secrets, private user data, or confidential business data. Cite external docs/snippets that materially shaped the work.

## Delivery Contribution

Use the unified delivery record in `GEMINI.md` to disclose changed/reviewed
files, material context and assumptions, checks, unverified gaps, residual risk,
and recommended human review. Do not add a second provenance report.
