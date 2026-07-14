---
name: implementation-execution-protocol
trigger: model_decision
description: Mandatory loop for coding tasks: context first, scoped edits, proportional verification, self-review, evidence-based delivery.
---

# Implementation Execution Protocol

Use for every task that creates, edits, deletes, configures, or reviews code.
Apply `rules/governance-router.md` first.

## 1. Classify Before Editing

Name: intent (feature/fix/refactor/test/config/docs/migration/release/investigation),
risk tier (trivial/standard/structural/critical), blast radius (files, modules,
APIs, data, jobs, UI, deps, ops), and acceptance evidence.

Risk floors: behavior change/bug fix => Standard; public API/contract,
cross-module boundary, schema, dependency, shared abstraction, or durable
architecture => Structural;
auth, secrets, PII/financial/regulated data, tenant isolation, destructive data,
production/shared-environment mutation, release execution, irreversible
operation, security/compliance exposure, or credible data loss/corruption/
duplication/cross-scope leakage => Critical. A self-contained new file or
ordinary persisted-data change does not raise the floor by itself. Highest
matching floor wins.

Trivial local edits can be terse. Standard+ work needs a brief plan before broad changes.

## 2. Discover Context

For existing code inspect: entry points/callers; input-to-output data flow;
contracts/errors/side effects/persistence; tests/fixtures; conventions for
naming, validation, errors, transactions, logging, deps, file layout; existing
utilities. Use project discovery tools if available; otherwise search/read code.
Never claim unavailable tools were used.

For standard+ work, record evidence anchors: files read, callers/contracts found,
tests/fixtures checked, and search terms or inspected locations for existing
helpers/patterns. If using an unfamiliar package/API, inspect installed source,
types, local usage, or official docs before naming methods, fields, routes, or
options. Do not infer third-party behavior from naming.

## 3. Choose Smallest Correct Approach

Answer: behavior/invariant changed or preserved; relevant edge cases; failure
response; scale/workload risk; conventions followed; tests/checks covering risk.

For standard+ work, compare at least:
- Existing/reuse path: local services, helpers, components, schemas, patterns.
- Smallest direct path: minimal change that is still correct and maintainable.
- Structural path: refactor/architecture change, only if the problem warrants it.

Record this decision artifact for standard+ work:

```
Decision:
- Existing/reuse path considered: [...]
- Smallest correct path considered: [...]
- Structural path considered: [...]
- Chosen approach: [...]
- Codebase evidence used: [...]
- Weaker options rejected because: [...]
- Verification evidence planned: [...]
```

Choose the strongest fit, not the fastest edit. Reject shortcut/prototype paths
unless explicitly requested. If a patch hides a deeper model problem, stop and
explain the refactor needed. For standard+ work, unsupported assertions about
available helpers, contracts, APIs, packages, fields, or routes are defects.

## 4. Implement Safely

Keep edits scoped; preserve public behavior unless requested; separate refactor
from behavior change; reuse fitting abstractions; add deps only when local/stdlib
options are inadequate and package risk is checked; use clear names, direct flow,
contextual errors. Do not invent unsupported behavior, APIs, fields, routes,
packages, permissions, migrations, or config. Do not revert unrelated user changes.

## 5. Verify Proportionally

Use the lightest meaningful checks, broaden by risk: unit/regression tests;
integration/contract/persistence tests; typecheck/lint/format/build/static
analysis; browser/manual UI checks; query-count/benchmark/profile/load-shaped
checks; security tests for auth, tenant isolation, secrets, untrusted input.
Diagnose failures; do not ship around them. Disclose checks not run and risk.

## 6. Self-Review

Before delivery check: actual request solved; no unrelated churn; conventions
preserved; null/empty/error/permission/concurrency/failure states handled;
algorithms/queries/memory appropriate; tests adequate; known issues fixed or
reported.

## Delivery Contribution

Feed implementation status, changed files, the material approach decision,
checks, gaps, and risks into the unified delivery record in `GEMINI.md`. Keep the
full decision artifact as an internal work record unless it materially helps the
user evaluate the result.

## Hard Rules

- No durable edits before relevant context.
- No standard+ edit without governance routing and evidence anchors.
- No "done" without verification or explicit gap.
- No symptom patch when root cause is knowable.
- No architecture bypass for speed.
- No durable shortcut, hardcode, or prototype implementation unless explicitly requested.
- No invented APIs/packages/fields/routes/contracts.
- No hidden known issues.
