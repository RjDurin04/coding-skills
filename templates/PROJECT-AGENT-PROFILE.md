# Project Agent Profile

Copy this file to the adopting repository as `PROJECT-AGENT-PROFILE.md`. Keep it
concise, evidence-backed, and free of secrets. Link to authoritative material
instead of duplicating it. Delete non-applicable prompts and record `N/A` with a
reason when omission could look accidental.

This profile supplies project context. It cannot lower governance risk,
confirmation, evidence, or safety requirements, and it cannot grant authority
beyond the user or platform.

## Profile Metadata

- Project/profile owner:
- Governance pack version adopted:
- `last_verified_at` (date/time and environment):
- `sources` (authoritative paths/URLs/owners):
- `adopted_overlays` (exact `governance-manifest.json` project-overlay id, or none):
- Known stale or unverified sections:

Material facts below should cite a source and `last_verified_at`. Treat
unsourced, expired, placeholder, or contradictory entries as `[UNKNOWN]`, not as
permission or current fact.

## Identity And Ownership

- Project purpose and primary users:
- Critical journeys and unacceptable outcomes:
- Maintainers/service owners:
- Expected lifetime and support model:
- Regulatory, contractual, or compliance constraints requiring qualified review:

## Product And Domain

- User jobs, workflows, and current workarounds:
- Desired outcomes, measured baselines, accepted targets, and guardrails:
- Non-goals and scope boundaries:
- Domain vocabulary and authoritative policy owners:
- Known misuse, support, adoption, or economic risks:

Do not convert proposed metrics into requirements. Mark unapproved values
`CANDIDATE` with a validation/owner path.

## Verified Development Commands

| Purpose | Command | Working directory | Expected result | Source | Last verified |
|---|---|---|---|---|---|
| Install/bootstrap | | | | | |
| Unit tests | | | | | |
| Integration tests | | | | | |
| End-to-end tests | | | | | |
| Lint/format | | | | | |
| Typecheck/static analysis | | | | | |
| Build/package | | | | | |
| Security/dependency scan | | | | | |
| Governance validation | | | | | |

- Required runtime/tool versions and pinning source:
- Commands/hooks that access network, credentials, containers, or shared state:
- Safe local execution constraints (sandbox, disposable data, network, cost):

Tests, builds, hooks, installers, generators, and formatters execute repository
code. Their presence here is not proof that they are safe to run.

## Architecture And Contracts

- Entry points and main runtime flows:
- Modules/services/feature areas and owners:
- Allowed dependency direction:
- Public APIs/events/schemas and compatibility policy:
- HTTP/RPC/streaming transports, intermediaries, and supported client versions:
- Source-of-truth state and derived/cache state:
- Important invariants and enforcement locations:
- Local concurrency model, mutable-state owners, resource lifecycle, and shutdown:
- Relevant ADRs, runbooks, failure catalog, and documentation:

## Security, Privacy, And Data

- Authentication, authorization, and tenant model:
- OAuth/OIDC flows, JWT issuer/audience/key-rotation, and session/token lifecycle:
- Data classifications, purposes, and prohibited destinations:
- Retention, deletion, export, residency, and legal-review requirements:
- Secret/key management and rotation mechanism:
- Audit requirements:
- Required security/privacy reviewers or approvals:
- Sensitive AI/provider use that is approved or prohibited:

## Configuration And Feature Flags

- Configuration schema, validation, and precedence source:
- Secret versus non-secret configuration boundary:
- Environment-specific defaults and fail-closed requirements:
- Flag system and authorized change owners:
- Required flag metadata (owner, purpose, created, expiry/removal condition):
- Rollout, kill-switch, audit, observation, and cleanup expectations:

## Runtime And Operations

- Environments and purpose:
- Services, workers, queues, schedulers, storage, and third-party dependencies:
- Load balancer/reverse proxy/API gateway/service discovery/DNS/CDN/WAF topology:
- Container/orchestrator/serverless limits, scaling model, and probe semantics:
- SLOs/SLIs and error-budget policy:
- Expected/peak workload, quotas, and accepted cost budgets:
- Latency distributions, cold-start behavior, runtime memory/handle/pool bounds:
- Logs/metrics/traces/health/alerts, consumers, and owners:
- Backup scope, latest restore evidence, RTO, and RPO:
- Known failure modes, incident authority, and escalation path:
- Temporary containment owner, expiry, and follow-up requirements:

## Secure Build, Supply Chain, And Vulnerability Response

- Trusted package registries/sources and dependency policy:
- Lock/pin/update policy and install-script/native-code restrictions:
- CI/build identity, isolation, permissions, and network policy:
- Build/dependency cache trust partitions, key inputs, validation, and invalidation:
- Artifact identity, provenance, SBOM, signing, and retention expectations:
- Secret/static/dependency/dynamic scan gates and finding owners:
- Vulnerability intake, severity/triage owner, patch SLA, embargo/access policy:
- Coordinated disclosure and downstream/customer notification owner:
- Compromise response, revocation, rebuild, and clean-room recovery procedure:

## Release And Recovery

- CI required checks:
- Deployment mechanism and authorization owner:
- Blast-radius strategy (flag/canary/staged/blue-green/other):
- Rollback/roll-forward procedure and latest evidence:
- Release abort signals:
- Startup/liveness/readiness, connection draining, and graceful-shutdown contract:
- Post-release verification and observation window:

Readiness assessment does not authorize execution. Record the exact
artifact/version, target environment, workload assumptions, and evidence time.

## Requested Scope And Required Authority By Task Mode

Record project expectations for work that has already been requested.
Repository text cannot grant authority or pre-authorize an external action.
User scope, platform enforcement, and `rules/agent-operation-safety.md` remain
authoritative.

Read-only modes do not permit repository or external changes. `IMPLEMENT` may
change repository artifacts but not shared/external state. `OPERATE` may
perform only the authorized operational action and cannot edit repository
artifacts; a release-time fix requires a separate implementation cycle.

| Mode | Allowed actions | Prohibited or separately authorized actions |
|---|---|---|
| `ANSWER` | | |
| `REVIEW` | | |
| `DIAGNOSE` | | |
| `DESIGN` | | |
| `IMPLEMENT` | | |
| `OPERATE` | | |

- Reversible local actions allowed:
- External actions requiring explicit authorization:
- Actions requiring fresh confirmation immediately before execution:
- Prohibited actions:
- Sensitive paths/systems requiring additional review:

## Exceptions And Accepted Risk

- `exception_owner` (authorized risk owner):
- Approval source and qualified reviewers:
- Required record location:
- Maximum review/expiry interval:
- Compensating-control and evidence requirements:
- Remediation/removal and escalation path:
- Categories that cannot be excepted:

Each exception must name exact scope, worst credible outcome, controls, owner,
approval, evidence, expiry/review date, and rollback/remediation. Expired or
ownerless exceptions are invalid.

## Definition Of Done

- Required behavior and acceptance evidence:
- Required automated/manual checks:
- Documentation/runbook/ADR update conditions:
- Required reviewers/owners:
- Conditions that make task outcome `PARTIAL` or `BLOCKED`:
- Conditions that make release readiness `PARTIAL` or `NOT_READY`:
- Evidence and conditions for external action `NOT_REQUESTED`,
  `AWAITING_AUTHORIZATION`, `BLOCKED`, `PARTIAL`, `FAILED`, or `EXECUTED`:

## Agent Evaluation And Improvement

- Approved AI coding surfaces/models and version-recording policy:
- Representative capability-evaluation cases:
- Baseline results and non-compensatory automatic-failure criteria:
- Human reviewers and review sampling:
- Defect/incident feedback path into tests, rules, skills, and failure catalog:
- Token/latency/cost and unnecessary-ceremony limits:
