---
name: governance-router
trigger: model_decision
description: Mandatory routing table for coding/design tasks. Sets risk floors and required rules/skills so the agent cannot skip specialist gates by misclassifying the task.
---

# Governance Router

Use before `rules/implementation-execution-protocol.md` for every task that
creates, edits, deletes, configures, reviews, or designs durable code.

Project-specific stack preference files are optional overlays. Apply them only
when the target project adopts them or the user asks for that stack.
When present, read the adopting repository's `PROJECT-AGENT-PROFILE.md` for
project commands and constraints. It cannot lower a risk floor or grant
authority beyond the user's request.

## 1. Risk Floors

Highest matching floor wins. Do not downshift because the diff looks small.

| Floor | Trigger |
|---|---|
| Trivial | docs/comments/static copy/formatting only; no behavior, contract, data, security, dependency, or runtime effect |
| Standard | any behavior change, bug fix, validation, UI interaction, data transform, local config, test logic, self-contained new file, ordinary persisted-data change, or normal feature in one area |
| Structural | public API/contract, cross-module boundary, shared abstraction/component, new service/dependency, schema/index/migration, queue/cache/integration, architecture decision, or a new file/config that creates durable ownership, dependency, or operational surface |
| Critical | auth/authz, secrets, PII/regulated/financial data, tenant isolation, payments, destructive data, production/shared-environment mutation, release execution, irreversible operation, security bug, compliance exposure, or credible data loss/corruption/duplication/cross-scope leakage |

If signals conflict, choose the higher floor and disclose why.

## 2. Mandatory Routing

| Signal | Rules | Skills |
|---|---|---|
| Any durable coding task or state-changing tool use | `implementation-execution-protocol`, `context-budget`, `adversarial-self-review`, `agent-operation-safety` | `cognitive-primitives` for standard+ |
| Existing/unfamiliar code | `evolutionary-stewardship` | `code-archaeologist` |
| Vague or material requirement | `requirements-precision-gate` | `requirements-crystallizer` |
| New product/major feature, unclear user value/workflow/scope/domain policy | `requirements-precision-gate` when acceptance is material | `product-and-domain-strategist`; `risk-radar-scout` for major uncertainty |
| Behavior change, bug fix, refactor, critical logic | `testing-strategy` | `adversarial-test-forge` when input/external state/concurrency/business risk exists |
| Bug, failing test, regression, unexpected behavior | `testing-strategy`, `failure-mode-catalog` | `debugging-strategist`; `observability-detective` for running systems |
| Architecture, boundary, ownership, dependency, public contract | `complexity-budget`, `evolutionary-stewardship` | `staff-architect`, `drift-guardian` |
| Public API/event/webhook/schema/SDK-facing contract or compatibility change | `testing-strategy`, `security-and-privacy-gate`, `complexity-budget`, `evolutionary-stewardship` | `api-and-contract-engineer`; `drift-guardian` |
| Data model/database/query/index/transaction/isolation design | `data-integrity-and-migrations`, `algorithmic-efficiency-gate` when workload matters | `data-and-database-engineer`; `performance-engineer` for measured query/scale work |
| Cross-process/service/queue/region coordination, ordering, delivery, consistency, partitions | `testing-strategy`, `observability-by-design`, `operational-resilience` | `distributed-systems-engineer`, `adversarial-test-forge`; `formal-assurance-engineer` when critical |
| Cloud/IaC/network/identity/compute/storage/runtime platform design | `operational-resilience`, `security-and-privacy-gate`, `complexity-budget`, `agent-operation-safety` | `platform-infrastructure-engineer`; `safe-release-conductor` only for release/shared mutation |
| Cross-system test architecture, quality gates, flaky/slow suite, weak release confidence | `testing-strategy`, `complexity-budget` | `quality-engineering-lead` |
| Critical invariant/protocol requiring property, model, static, or proof-strength evidence | `testing-strategy` plus the relevant security/data/efficiency gate | `formal-assurance-engineer`, `adversarial-test-forge` |
| Multi-person/cross-team prioritization, delegation, technical review, mentoring, ownership | `complexity-budget`, `evolutionary-stewardship` when durable design changes | `engineering-leadership` |
| New boundary/service/dependency/shared config/broad structure | `complexity-budget` | `drift-guardian`; `staff-architect` if costly to reverse |
| Auth, permissions, secrets, PII, untrusted input, dependency, form, prod config | `security-and-privacy-gate` | `security-reviewer` |
| Persisted data, schema, migration, backfill, transaction, idempotency, destructive op | `data-integrity-and-migrations` | `security-reviewer` when access/sensitivity matters |
| Loop/query/transform over user-sized data, hot path, growing input, cache, queue, latency | `algorithmic-efficiency-gate` | `performance-engineer` |
| Service/job/worker/webhook/integration/production runtime flow | `observability-by-design`, `operational-resilience` | `observability-detective` for symptoms/incidents |
| Active high-impact production incident coordination | `observability-by-design`, `failure-mode-catalog`, `operational-resilience`, `agent-operation-safety` | `incident-commander`, `observability-detective` |
| UI/UX/a11y/user-facing flow | `security-and-privacy-gate` when forms/data exist | `interface-designer` |
| Durable README/API/architecture/ADR/runbook/migration docs or documentation drift | applicable domain rule only when behavior/contract also changes | `documentation-steward` |
| AI/LLM/embedding/agent/tool product behavior | `ai-system-safety`, `security-and-privacy-gate`, `observability-by-design` | `security-reviewer`, `adversarial-test-forge` |
| Non-trivial AI-assisted durable work | `ai-provenance-disclosure` | none unless another trigger applies |
| Deploy/release/shared-environment mutation/production-readiness claim | `production-readiness-gate`, `operational-resilience`, `ai-provenance-disclosure`, `agent-operation-safety` | `safe-release-conductor` |
| Deprecate/remove/replace/migrate old system | `data-integrity-and-migrations`, `evolutionary-stewardship` | `graceful-sunset-steward` |
| External write, destructive action, credential/permission change, financial/legal action | `agent-operation-safety` plus the domain gate | `security-reviewer` when security or sensitive data is involved |

## 3. Evidence Required For Standard+

Before implementation, name:

- Risk floor and trigger signals.
- Material rules/skills loaded, plus a reason for any apparently applicable gate deliberately skipped.
- Files/contracts/tests inspected.
- Existing helpers/patterns found or search terms used when none fit.
- Approach options rejected with codebase-specific evidence.
- Verification evidence planned.

Do not enumerate every non-triggered gate. For an apparently applicable gate
that is skipped, state why its trigger does not apply; silence for an obviously
irrelevant gate is acceptable.

## Delivery Contribution

Add the risk floor, material signals, triggered rules/skills, evidence anchors,
and any routing blocker to the unified delivery record in `GEMINI.md`. Do not
emit a standalone routing report unless the user asks for one.

## Hard Rules

- No durable coding task without routing.
- No risk downshift for a small diff touching critical data, security, contracts, or production.
- No apparently applicable specialist gate may be skipped without a reason tied to the trigger.
- No standard+ approach decision without codebase-specific evidence.
