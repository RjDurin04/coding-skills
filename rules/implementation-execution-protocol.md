---
name: implementation-execution-protocol
trigger: model_decision
description: Mandatory loop for IMPLEMENT tasks: context first, scoped edits, proportional verification, self-review, and evidence-based delivery.
---

# Implementation Execution Protocol

Use only when the requested mode includes `IMPLEMENT`: creating, editing,
deleting, or configuring durable repository artifacts. `ANSWER`, `REVIEW`,
`DIAGNOSE`, and `DESIGN` remain read-only unless implementation is separately
requested. `OPERATE` governs shared/external mutation, not repository
edits. Apply `rules/governance-router.md` first.

## 1. Classify Before Editing

Name the intended behavior, acceptance evidence, manifest routing signals,
effective risk, blast radius, and local action authority. The manifest supplies
risk floors. Discovery may change matching signals, but never downshift while a
higher-floor trigger remains.

Trivial edits can be terse. Standard work needs one concise evidence-backed
decision. Structural/Critical work needs explicit boundaries, meaningful
alternatives, compatibility/recovery, and a verification plan.

## 2. Discover Context

For existing code inspect the relevant entry point and callers; input-to-output
flow; contracts, errors, side effects, and persistence; tests/fixtures; local
conventions; existing owners/helpers; and current uncommitted work.

For Standard+ work retain evidence anchors: files read, contracts/callers found,
tests checked, and search terms or locations inspected for reuse. For an
unfamiliar package or API, inspect installed source/types/local usage or current
official documentation. Do not infer behavior from naming.

## 3. Select The Smallest Correct Fit

State the invariant or behavior changed/preserved, material edge/failure cases,
scale risk, existing pattern used, and evidence planned.

- Standard: compare reuse with the smallest direct change; mention a structural
  alternative only when there is real pressure for one.
- Structural/Critical: compare meaningful local, direct, and structural options;
  record why rejected choices fail on correctness, risk, fit, lifecycle cost, or
  reversibility.

Do not generate alternatives merely to satisfy ceremony. If the patch would
hide a deeper model failure, stop and explain the required design change.

## 4. Implement Safely

- Keep edits within the requested scope and preserve public behavior unless the
  request changes it.
- Separate refactoring from behavior change and preserve unrelated user work.
- Reuse a fitting owner; add structure or dependencies only when they reduce
  total lifecycle risk or protect a real boundary/invariant.
- Enforce validation, authorization, data integrity, bounded resources, and
  contextual safe errors at the appropriate layer.
- Do not invent behavior, APIs, fields, routes, packages, permissions,
  migrations, configuration, or numeric requirements.

If release-time repository changes are needed, remain in or return to
`IMPLEMENT`, verify them, then separately enter `OPERATE`; implementation
authority never implies release authority.

## 5. Verify Proportionally

Use the lightest checks capable of falsifying material claims, broadened by
risk: focused/regression tests; integration/contract/persistence tests;
type/lint/format/build/static checks; UI/manual checks; query/benchmark/profile;
and security/tenancy/failure tests.

Tests, builds, hooks, installers, generators, and formatters execute code. Apply
`rules/agent-operation-safety.md` before running them and
`rules/supply-chain-and-build-integrity.md` when build/dependency trust matters.
Diagnose failures; do not ship around them. Record environment, evidence time or
artifact version, and unverified target-environment gaps.

## 6. Self-Review And Deliver

Check that the actual request is solved, churn is scoped, contracts and
conventions are preserved, material failure/permission/concurrency/limit states
are handled, resource shape is appropriate, and evidence supports each claim.

Feed changed files, the material decision, checks, gaps, and risks into the
unified delivery record in `GEMINI.md`. Task completion must remain separate
from release readiness and external-action status.

## Hard Rules

- No durable edit before relevant context and routing.
- No Standard+ edit without evidence anchors.
- No invented interfaces, requirements, results, or authority.
- No symptom patch when the root cause is knowable and in scope.
- No production/shared mutation under `IMPLEMENT`.
- No "done" without proportional verification or an explicit gap.
