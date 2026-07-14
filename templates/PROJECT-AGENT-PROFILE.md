# Project Agent Profile

Copy this file to the adopting repository as `PROJECT-AGENT-PROFILE.md`. Keep it
concise, evidence-backed, and free of secrets. Delete non-applicable prompts and
link to authoritative project documents instead of duplicating them.

## Identity And Ownership

- Project purpose:
- Primary users and critical journeys:
- Maintainers/owners:
- Expected lifetime and support model:
- Regulated, contractual, or compliance constraints requiring qualified review:

## Product And Domain

- Primary user jobs, workflows, and current workarounds:
- Desired outcomes, baselines, targets, and guardrail metrics:
- Non-goals and scope boundaries:
- Domain vocabulary and authoritative business-policy owners:
- Known adoption, support, misuse, or economic risks:

## Verified Development Commands

| Purpose | Command | Working directory | Expected result |
|---|---|---|---|
| Install/bootstrap | | | |
| Unit tests | | | |
| Integration tests | | | |
| End-to-end tests | | | |
| Lint/format | | | |
| Typecheck/static analysis | | | |
| Build/package | | | |
| Security/dependency scan | | | |
| Governance validation | | | |

State required runtime/tool versions and where they are pinned. Do not put tokens,
credentials, or private endpoints here.

## Architecture And Contracts

- Entry points and main runtime flows:
- Modules/services/feature areas and owners:
- Allowed dependency direction:
- Public APIs/events/schemas and compatibility policy:
- Source-of-truth data and derived/cache data:
- Important invariants and where they are enforced:
- Relevant ADRs, runbooks, failure catalog, and documentation:

## Security, Privacy, And Data

- Authentication/authorization/tenant model:
- Data classifications and prohibited destinations:
- Retention/deletion/export/residency requirements:
- Secret/key management and rotation mechanism:
- Audit requirements:
- Required security/privacy reviewers or approvals:

## Runtime And Operations

- Environments and their purpose:
- Services, workers, queues, schedulers, storage, and third-party dependencies:
- SLOs/SLIs and error-budget policy:
- Expected/peak workload, quotas, and cost budgets:
- Logs/metrics/traces/health/alerts and owners:
- Backup scope, restore evidence, RTO, and RPO:
- Known failure modes and escalation path:

## Release And Recovery

- CI required checks:
- Artifact/build provenance and SBOM/signing expectations:
- Deployment mechanism and authorization owner:
- Blast-radius strategy (flag/canary/staged/blue-green/other):
- Rollback/roll-forward procedure:
- Release abort signals:
- Post-release verification and observation window:

## Agent Authority

List what the agent may do within an explicit implementation request. Platform
approval mechanisms and `rules/agent-operation-safety.md` still apply.

- Reversible local actions allowed:
- External actions allowed only when explicitly requested:
- Actions requiring fresh confirmation:
- Prohibited actions:
- Sensitive paths/systems requiring additional review:

## Definition Of Done

- Required behavior and acceptance evidence:
- Required automated/manual checks:
- Documentation/runbook/ADR update conditions:
- Required reviewers/owners:
- Conditions that make the result `PARTIAL` or `NOT READY`:

## Agent Evaluation And Improvement

- Approved AI coding surfaces/models and version-recording policy:
- Representative capability-evaluation cases for this project:
- Baseline scores and automatic-failure conditions:
- Human reviewers and review sampling frequency:
- Defect/incident feedback path into tests, rules, skills, and failure catalog:
- Token/latency/cost and unnecessary-ceremony limits:
