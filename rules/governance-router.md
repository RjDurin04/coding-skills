---
name: governance-router
trigger: model_decision
description: Mandatory compositional router for engineering task mode, risk, rules, specialist skills, authority, and confirmation.
---

# Governance Router

Use this router for every engineering task governed by the pack.
`governance-manifest.json` is the sole machine-readable authority for task
modes, routing signals, risk floors, confirmation levels, rules, skills, and
project overlays. The generated sections below are views of that manifest; do
not edit them by hand.

## 1. Select One Task Mode

Choose the mode that matches the user's requested outcome, not the actions that
might be convenient. A mode limits actions; it never grants authority.

<!-- BEGIN GENERATED: TASK MODES -->
| Mode | Repository changes | External effects | Required signals | Description |
|---|---:|---:|---|---|
| `answer` | false | false | `durable_task` | Explain or answer without changing repository artifacts or causing external effects. |
| `review` | false | false | `durable_task` | Inspect and report findings without changing repository artifacts or causing external effects. |
| `diagnose` | false | false | `durable_task` | Determine cause and gather evidence without implementing a fix or causing external effects. |
| `design` | false | false | `durable_task` | Produce a decision, specification, or plan without changing repository artifacts or causing external effects. |
| `implement` | true | false | `durable_task`, `implementation_task` | Create or change repository artifacts, verify the result locally, and stop before external or shared-environment effects. |
| `operate` | false | true | `durable_task`, `operational_action` | Perform a specifically authorized operational, shared-environment, external, or release action without changing repository artifacts; operation-time edits require a separate implement-mode cycle. |
<!-- END GENERATED: TASK MODES -->
If the requested outcome changes, route again before acting. In particular:

- `REVIEW`, `DIAGNOSE`, and `DESIGN` do not authorize implementation.
- `IMPLEMENT` permits scoped repository changes, not external effects.
- `OPERATE` permits only the specifically authorized operational action. It
  does not permit opportunistic repository edits.
- An operation-time code or repository-configuration fix requires a separate
  `IMPLEMENT` cycle, verification, and then a newly routed `OPERATE`
  cycle.

## 2. Compose All Matching Signals

Start with the mode's `required_signals`. Then add every signal whose
description materially matches the task:

1. After mode-required signals, put the signal for the user's explicitly stated
   primary outcome first.
2. If no single primary outcome is explicit, prefer the matching signal with
   the highest risk floor, then the highest confirmation level, then manifest
   declaration order. This is the deterministic tie-break.
3. Add remaining matching signals in manifest declaration order.
4. Do not omit a signal merely because another signal already raises the risk.
5. Record any apparently applicable signal deliberately excluded and the
   concrete reason its trigger does not apply.

Composition is deterministic:

- Risk is the highest matching `minimum_risk`.
- Confirmation is the highest matching `confirmation`.
- Rules are the de-duplicated union of every matching signal and risk overlay.
- The first non-null `lead_skill` in ordered signals is the lead.
- Later non-null leads and all `supporting_skills` become supporting skills;
  de-duplicate them and exclude the selected lead.
- Load only the lead and materially relevant supporting skills.

<!-- BEGIN GENERATED: ROUTING SIGNALS -->
| Signal | Minimum risk | Confirmation | Rules | Lead skill | Supporting skills | Description |
|---|---|---|---|---|---|---|
| `active_incident_coordination` | `critical` | `none` | `observability-by-design`, `failure-mode-catalog`, `operational-resilience`, `agent-operation-safety` | `incident-commander` | `observability-detective` | A high-impact incident needs coordination, containment planning, evidence tracking, communication, and recovery without authorizing live mutation by itself. |
| `ai_product_behavior` | `standard` | `none` | `ai-system-safety`, `security-and-privacy-gate`, `observability-by-design` | `ai-system-and-evaluation-engineer` | `adversarial-test-forge`, `security-reviewer` | LLM, embedding, retrieval, classifier, agent, model, or tool-using product behavior changes and needs explicit evaluation. |
| `algorithmic_efficiency` | `standard` | `none` | `algorithmic-efficiency-gate` | `performance-engineer` | none | A hot path, query, loop, transform, cache, queue, latency target, or user-sized and growing workload needs complexity or performance analysis. |
| `api_contract` | `structural` | `none` | `testing-strategy`, `security-and-privacy-gate`, `complexity-budget`, `evolutionary-stewardship` | `api-and-contract-engineer` | `drift-guardian` | A public API, event, webhook, protocol, schema, SDK-facing surface, versioning policy, or compatibility contract changes. |
| `architecture_or_public_boundary` | `structural` | `none` | `complexity-budget`, `evolutionary-stewardship` | `staff-architect` | `drift-guardian` | A public contract, ownership boundary, shared abstraction, service boundary, or costly-to-reverse architecture decision changes. |
| `artifact_build_or_distribution` | `structural` | `none` | `supply-chain-and-build-integrity` | `safe-release-conductor` | `security-reviewer` | A release artifact is packaged, signed, attested, promoted, distributed, or published, or its provenance and identity controls change. |
| `behavior_change` | `standard` | `none` | `testing-strategy` | none | none | Observable runtime, contract, validation, state, or user behavior changes. |
| `bounded_credential_or_permission_action` | `standard` | `explicit_authorization` | `agent-operation-safety`, `security-and-privacy-gate` | `security-reviewer` | none | A specifically scoped, reversible credential or permission action is confined to a local or isolated non-production environment and does not expand privilege, transfer ownership, expose sensitive data, or create material downstream impact. |
| `bug_or_regression` | `standard` | `none` | `testing-strategy` | `debugging-strategist` | none | A failing test, defect, regression, or unexpected behavior needs evidence-led diagnosis or correction. |
| `complex_reasoning_or_state_model` | `standard` | `none` | none | none | `cognitive-primitives` | The task needs explicit invariants, state transitions, multi-step decomposition, competing-constraint analysis, or a non-obvious approach decision. |
| `configuration_or_feature_flag` | `standard` | `none` | `configuration-and-feature-flags` | none | `drift-guardian` | Runtime configuration, environment-dependent behavior, feature flags, kill switches, or temporary operational controls change. |
| `credential_permission_financial_or_legal_action` | `critical` | `fresh_confirmation` | `agent-operation-safety`, `security-and-privacy-gate` | `security-reviewer` | none | An action changes production, shared, or privileged credentials or permissions; expands privilege; transfers ownership; commits funds; creates a legal obligation; or signs, approves, or makes one of those consequential decisions on another party's behalf. |
| `credible_high_impact_harm` | `critical` | `none` | `adversarial-self-review`, `failure-mode-catalog`, `security-and-privacy-gate` | `risk-radar-scout` | `adversarial-test-forge`, `security-reviewer` | The task has a credible path to high-impact harm involving human safety, health, rights, employment, finances, privacy, or security, or material system integrity or availability, and no more specific Critical signal already represents the same consequence. |
| `critical_data_integrity` | `critical` | `none` | `data-integrity-and-migrations`, `security-and-privacy-gate` | `data-and-database-engineer` | `security-reviewer`, `adversarial-test-forge` | A credible failure could corrupt, lose, duplicate, misattribute, or leak material data across an authorization or ownership scope. |
| `cross_team_technical_leadership` | `standard` | `none` | none | `engineering-leadership` | none | Multi-person or cross-team prioritization, delegation, ownership, technical review, mentoring, or decision facilitation is needed. |
| `database_design` | `structural` | `none` | `data-integrity-and-migrations` | `data-and-database-engineer` | none | A data model, query shape, index, transaction, isolation, ownership, or database architecture decision changes. |
| `dependency_change` | `structural` | `none` | `complexity-budget`, `supply-chain-and-build-integrity`, `security-and-privacy-gate` | `drift-guardian` | `security-reviewer` | A new or materially changed runtime dependency, framework, hosted service, or vendor commitment is proposed. |
| `deprecation_or_replacement` | `structural` | `none` | `data-integrity-and-migrations`, `evolutionary-stewardship` | `graceful-sunset-steward` | `drift-guardian` | An old interface, behavior, data shape, dependency, service, or system will be deprecated, migrated, replaced, or removed. |
| `destructive_or_irreversible_action` | `critical` | `fresh_confirmation` | `agent-operation-safety`, `data-integrity-and-migrations` | `security-reviewer` | none | An action materially deletes, overwrites, rotates, revokes, destroys, or makes valuable state difficult to recover; scoped reviewable version-controlled edits with a verified recovery path do not match. |
| `distributed_system` | `structural` | `none` | `testing-strategy`, `observability-by-design`, `operational-resilience` | `distributed-systems-engineer` | `adversarial-test-forge` | Cross-process, cross-service, queue, region, ordering, delivery, consistency, retry, or partition behavior changes. |
| `documentation_stewardship` | `trivial` | `none` | none | `documentation-steward` | none | A durable README, API guide, architecture record, runbook, migration guide, or documentation-drift decision is needed. |
| `durable_task` | `trivial` | `none` | `governance-router`, `context-budget`, `adversarial-self-review`, `agent-operation-safety` | none | none | Any engineering answer, review, diagnosis, design, implementation, or operation governed by this pack. |
| `established_security_boundary` | `standard` | `none` | `security-and-privacy-gate` | `security-reviewer` | none | Bounded work touches an established, unchanged authentication, authorization, tenant-isolation, secret-handling, or other security boundary without expanding privilege, data exposure, or trust. |
| `existing_unfamiliar_code` | `standard` | `none` | `evolutionary-stewardship` | `code-archaeologist` | none | Work in an existing or unfamiliar codebase where behavior, ownership, or local conventions must be discovered before decisions are made. |
| `external_side_effect` | `standard` | `explicit_authorization` | `agent-operation-safety` | none | none | An action will write to an external service, contact another person, publish content, create a remote resource, or otherwise cause an effect outside the local workspace. |
| `formal_assurance` | `structural` | `none` | `testing-strategy` | `formal-assurance-engineer` | `adversarial-test-forge` | A material invariant, protocol, or algorithm needs property-based, model-based, static, proof-strength, or other formalized evidence. |
| `implementation_task` | `trivial` | `none` | `implementation-execution-protocol` | none | none | Creation, modification, movement, or deletion of durable repository artifacts. |
| `major_project_uncertainty` | `structural` | `none` | `requirements-precision-gate`, `complexity-budget` | `risk-radar-scout` | `product-and-domain-strategist` | Material uncertainty spans scope, ownership, feasibility, safety, cost, or reversibility and needs explicit risk reduction. |
| `material_public_communication` | `critical` | `fresh_confirmation` | `agent-operation-safety` | none | none | An external communication is legally binding, security- or incident-sensitive, mass-distributed, or materially difficult to retract without reputational or user harm. |
| `material_requirement_or_constraint` | `standard` | `none` | `requirements-precision-gate` | none | none | A clear accepted high-stakes, consequential, cross-boundary, or architecturally significant requirement or constraint materially determines correctness, quality, security, privacy, cost, compatibility, or a public contract. |
| `new_durable_boundary` | `structural` | `none` | `complexity-budget` | `drift-guardian` | `staff-architect` | A new service, module, shared component, durable configuration surface, or long-lived ownership boundary is proposed. |
| `nontrivial_ai_assisted_work` | `trivial` | `none` | `ai-provenance-disclosure` | none | none | AI materially assisted a durable engineering artifact or decision and provenance must be disclosed. |
| `operational_action` | `standard` | `none` | `agent-operation-safety` | none | none | A non-repository operational action will change local runtime, shared, or external state under OPERATE. |
| `persisted_data` | `standard` | `none` | `data-integrity-and-migrations` | none | none | Persisted state, transactions, idempotency, durable identifiers, or stored data behavior changes. |
| `platform_infrastructure` | `structural` | `none` | `operational-resilience`, `security-and-privacy-gate`, `complexity-budget`, `agent-operation-safety`, `supply-chain-and-build-integrity` | `platform-infrastructure-engineer` | `drift-guardian`, `security-reviewer` | Cloud, infrastructure as code, network, identity, compute, storage, runtime platform, or environment topology changes. |
| `privacy_lifecycle` | `structural` | `none` | `security-and-privacy-gate`, `data-integrity-and-migrations` | `privacy-and-data-governance-engineer` | `security-reviewer` | Consent, purpose limitation, collection, retention, deletion, subject rights, residency, or material privacy-governance behavior changes. |
| `product_domain_discovery` | `standard` | `none` | `requirements-precision-gate` | `product-and-domain-strategist` | none | User value, business workflow, domain policy, success criteria, or the smallest useful product scope needs discovery. |
| `production_incident_change` | `critical` | `fresh_confirmation` | `observability-by-design`, `operational-resilience`, `production-readiness-gate`, `agent-operation-safety` | `incident-commander` | `observability-detective`, `safe-release-conductor` | A live production incident response will mutate production or a shared environment. |
| `production_readiness_assessment` | `structural` | `none` | `production-readiness-gate`, `operational-resilience` | `safe-release-conductor` | none | A production-ready, shippable, deployable, or release-readiness claim is evaluated. |
| `production_runtime_flow` | `standard` | `none` | `observability-by-design`, `operational-resilience` | none | none | A service, worker, job, webhook, integration, or other production runtime flow changes. |
| `pure_refactor` | `standard` | `none` | `testing-strategy`, `evolutionary-stewardship` | `refactoring-mechanic` | none | Internal structure changes while observable behavior and public contracts are intended to remain unchanged. |
| `quality_strategy` | `structural` | `none` | `testing-strategy`, `complexity-budget` | `quality-engineering-lead` | none | Cross-system test architecture, quality gates, a flaky or slow suite, or release-confidence strategy changes. |
| `recurring_or_bounded_operational_failure` | `standard` | `none` | `failure-mode-catalog`, `operational-resilience` | `observability-detective` | `debugging-strategist` | A recurring or operationally significant but bounded failure needs durable detection, ownership, mitigation, or prevention. |
| `release_design_or_configuration` | `structural` | `none` | `operational-resilience`, `configuration-and-feature-flags` | `safe-release-conductor` | none | A release strategy, rollback design, deployment configuration, staged rollout, or release control is designed or changed without executing it. |
| `repository_code_execution` | `trivial` | `none` | `agent-operation-safety` | none | none | Repository-controlled tests, builds, generators, hooks, migrations, installers, or other scripts will execute locally. |
| `running_system_symptom` | `standard` | `none` | `observability-by-design` | `observability-detective` | `debugging-strategist` | A symptom in a running system requires telemetry-led investigation. |
| `schema_or_migration` | `structural` | `none` | `data-integrity-and-migrations` | `data-and-database-engineer` | `drift-guardian` | A schema, index, migration, backfill, or compatibility transition for persisted data changes. |
| `security_relevant_configuration` | `structural` | `none` | `configuration-and-feature-flags`, `security-and-privacy-gate` | `security-reviewer` | `drift-guardian` | Configuration materially changes authentication, authorization, secrets, TLS, origin or network trust, security headers, execution permissions, or data-exposure controls. |
| `security_sensitive` | `critical` | `none` | `security-and-privacy-gate` | `security-reviewer` | `adversarial-test-forge` | A new, changed, or high-impact authentication, authorization, tenant-isolation, secret-handling, or sensitive trust boundary is involved, or there is a material security vulnerability or credible regulated, bulk, or cross-tenant data exposure. |
| `sensitive_data_handling` | `standard` | `none` | `security-and-privacy-gate` | `privacy-and-data-governance-engineer` | `security-reviewer` | Personal or sensitive data is handled within an established and approved trust boundary without creating a new high-impact boundary. |
| `shared_environment_release_execution` | `critical` | `fresh_confirmation` | `production-readiness-gate`, `operational-resilience`, `agent-operation-safety` | `safe-release-conductor` | none | A production deployment, release, promotion, rollout, or a material or difficult-to-recover shared-environment release mutation will actually execute. |
| `supply_chain_advisory_or_bounded_vulnerability` | `standard` | `none` | `supply-chain-and-build-integrity`, `security-and-privacy-gate` | `security-reviewer` | none | A dependency or build advisory, or a bounded vulnerability with no credible active compromise or material security impact, requires intake and assessment. |
| `supply_chain_change` | `standard` | `none` | `supply-chain-and-build-integrity`, `security-and-privacy-gate` | none | `security-reviewer` | A package version, lockfile, package source, build script, CI action, generated artifact, or dependency trust decision changes. |
| `supply_chain_vulnerability_or_compromise` | `critical` | `none` | `supply-chain-and-build-integrity`, `security-and-privacy-gate` | `security-reviewer` | `adversarial-test-forge` | A material supply-chain vulnerability, suspected malicious package or source, or suspected or confirmed compromised build path requires assessment or response. |
| `test_logic_or_verification_change` | `standard` | `none` | `testing-strategy` | none | none | Executable tests, fixtures, assertions, test harnesses, or verification logic change without changing production behavior. |
| `unfamiliar_or_privileged_repository_execution` | `standard` | `none` | `agent-operation-safety`, `supply-chain-and-build-integrity` | none | none | Repository-controlled code is unfamiliar, mutation-prone, networked, installer- or hook-driven, or would run with credentials, elevated privileges, broad filesystem access, or material cost. |
| `untrusted_input_or_data_access` | `standard` | `none` | `security-and-privacy-gate` | none | none | Code parses untrusted input, constructs a database or search query, resolves an object scope, or exposes a data-access boundary. |
| `user_interface` | `standard` | `none` | none | `interface-designer` | none | A user-facing interaction, workflow, accessibility behavior, or visual information hierarchy changes. |
| `user_interface_with_data` | `standard` | `none` | `security-and-privacy-gate` | `interface-designer` | none | A form or user interface reads, submits, reveals, or transforms application data. |
| `vague_material_requirement` | `standard` | `none` | `requirements-precision-gate` | `requirements-crystallizer` | none | A material requirement, acceptance boundary, policy, or constraint is ambiguous or conflicting. |
<!-- END GENERATED: ROUTING SIGNALS -->
## 3. Apply Risk Overlays

Apply an overlay when the composed risk is at or above its
`minimum_risk`. Overlays add controls; they never remove signal requirements.

<!-- BEGIN GENERATED: RISK OVERLAYS -->
| Applies at or above | Rules | Supporting skills |
|---|---|---|
| none | none | none |
<!-- END GENERATED: RISK OVERLAYS -->
Risk is consequence-based:

- `TRIVIAL`: no runtime, contract, data, security, dependency, or operational
  consequence.
- `STANDARD`: bounded behavior or maintainability work in an established
  boundary, with recoverable failure.
- `STRUCTURAL`: a durable boundary, public contract, schema, dependency,
  ownership surface, or costly-to-reverse design changes.
- `CRITICAL`: a credible failure can cause material security, authorization,
  privacy, financial, legal, production, cross-tenant, irreversible, or
  high-impact data harm.

Small diffs do not lower risk. Conversely, the mere presence of routine data,
formal methods, leadership, or release planning does not make a task Critical;
the consequence trigger must match.

## 4. Resolve Authority and Conflicts

Interpret confirmation levels as follows:

- `none`: no additional confirmation is required by routing, but the user must
  still have authorized the task's scope.
- `explicit_authorization`: the current user request must clearly encompass the
  exact class of external effect. Ambiguous or inferred authority is
  insufficient.
- `fresh_confirmation`: pause immediately before execution, show the resolved
  target, effect, recovery path, and material risk, and obtain a new
  confirmation even if the broader task was previously approved.

Higher-priority instructions always win. For equal-authority instructions that
cannot both be satisfied, preserve safety and reversibility, do not silently
choose a materially different outcome, and ask only when the conflict affects
correctness, security, data, cost, external effects, or irreversible design.

Project profiles and overlays may add commands, conventions, or stricter gates.
They cannot lower a risk floor, remove a required control, grant authority, or
override higher-priority instructions. Apply an overlay only when the adopting
project's `PROJECT-AGENT-PROFILE.md` explicitly names its manifest id.

## 5. Scale Evidence Without Ceremony

- `TRIVIAL`: use the smallest relevant inspection and check. Do not manufacture
  architecture, threat-model, rollout, or benchmark artifacts.
- `STANDARD`: inspect the affected seam and consumers, preserve local
  conventions, and run focused checks that could falsify the change.
- `STRUCTURAL`: make contracts, alternatives, compatibility, migration,
  operability, and rollback evidence explicit where applicable.
- `CRITICAL`: analyze credible abuse and failure paths, verify decisive
  controls independently where practical, and leave unresolved high-impact
  uncertainty visible.

Evidence supports only the claim, environment, configuration, revision, and
time actually checked. Never convert a narrow or stale check into a broad
production-readiness claim.

## Hard Rules

- Do not perform a durable engineering task without selecting a mode and
  composing its signals.
- Do not use `implementation-execution-protocol` outside `IMPLEMENT`.
- Do not treat planning, review, diagnosis, or a readiness assessment as
  authorization to change files or operate a shared environment.
- Do not downshift risk because the diff is small or upshift merely to appear
  rigorous.
- Do not claim production-ready, shippable, deployable, or successfully
  released unless the applicable gate passes with current evidence.
