# Portable AI Software Engineering Governance Pack

This repository is an IDE-neutral governance pack for AI-assisted software
engineering. It helps an AI agent choose an appropriate task mode, calibrate
rigor to consequence, apply relevant engineering rules and specialist
procedures, respect action authority, verify its work, and report results
without overstating certainty or release readiness.

The pack is intended for real software repositories. It covers implementation,
review, diagnosis, design, testing, security, privacy, data integrity,
performance, architecture, operations, documentation, AI systems, supply-chain
integrity, and release readiness.

## What This Pack Does

For each engineering task, the pack guides the agent through this flow:

```text
user request
    -> task mode
    -> matching routing signals
    -> risk and confirmation level
    -> required rules
    -> one lead skill plus bounded supporting skills
    -> scoped action and verification
    -> evidence-based delivery
```

It deliberately separates three questions:

1. **Is the requested task complete?**
2. **Is a named artifact ready for a named production environment?**
3. **Was an authorized external or operational action actually executed?**

A passing local test does not answer all three.

## Core Concepts

### Task modes

Mode controls what the agent may do. Risk controls how rigorously it must do it.

| Mode | Purpose |
|---|---|
| `ANSWER` | Explain or advise without changing repository or external state. |
| `REVIEW` | Inspect and report findings without implementing changes. |
| `DIAGNOSE` | Reproduce and identify causes without implementing a fix. |
| `DESIGN` | Produce decisions, contracts, or plans without durable edits. |
| `IMPLEMENT` | Make reversible local repository changes and verify them. |
| `OPERATE` | Perform a specifically authorized external, shared, or production action. |

Read-only modes do not silently become implementation. Implementation authority
does not imply permission to deploy, publish, message people, change
credentials, or mutate shared systems.

### Consequence-based risk

The manifest composes `trivial`, `standard`, `structural`, and `critical` risk
floors from every matching routing signal. A small diff can still be Critical
when it changes a high-impact trust or data boundary. A larger but bounded,
reversible documentation change need not be treated like a production
migration.

### Rules, skills, and overlays

- **Rules** are mandatory engineering gates selected by routing signals.
- **Skills** are focused procedures for a particular kind of work. The router
  prefers one lead skill and only materially relevant supporting skills.
- **Overlays** are optional project preferences. They activate only when an
  adopting project's profile explicitly names them.

Rules and skills cannot grant missing authority or weaken higher-priority
instructions.

## Repository Map

| Path | Purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Portable entry instructions for an AI coding tool. |
| [`GEMINI.md`](GEMINI.md) | Compact normative governance layer and delivery contract. |
| [`governance-manifest.json`](governance-manifest.json) | Authoritative machine-readable inventory and routing source. |
| [`rules/`](rules/) | Triggered engineering, safety, verification, and readiness gates. |
| [`skills/`](skills/) | Specialist task procedures. |
| [`overlays/`](overlays/) | Optional, explicitly adopted project preferences. |
| [`templates/PROJECT-AGENT-PROFILE.md`](templates/PROJECT-AGENT-PROFILE.md) | Template for repository-specific context. |
| [`schemas/`](schemas/) | JSON Schemas for the manifest and evaluation artifacts. |
| [`tests/`](tests/) | Routing scenarios, capability cases, scorers, and negative tests. |
| [`scripts/test-governance.ps1`](scripts/test-governance.ps1) | Canonical aggregate validation command. |
| [`.github/workflows/governance.yml`](.github/workflows/governance.yml) | Windows and Linux CI validation. |

The current pack version, rule inventory, skill inventory, routing signals, and
available overlay identifiers live in
[`governance-manifest.json`](governance-manifest.json). Do not duplicate that
inventory in project profiles.

## Adopt The Pack In A Project

An **adopting project** is another repository that chooses to use this pack.
Keep the pack together because its entry files reference the manifest, rules,
skills, schemas, and templates by relative path.

### 1. Place the pack in the project

Vendor, copy, or otherwise make the complete pack available in the adopting
repository. A non-conflicting layout is:

```text
my-project/
|-- AGENTS.md
|-- PROJECT-AGENT-PROFILE.md
|-- .agents/
|   |-- AGENTS.md
|   |-- GEMINI.md
|   |-- governance-manifest.json
|   |-- rules/
|   |-- skills/
|   |-- overlays/
|   |-- schemas/
|   |-- scripts/
|   `-- tests/
|-- src/
`-- tests/
```

Do not copy only one entry file unless you also adjust its references to the
rest of the pack.

### 2. Connect the AI tool's entry file

Use the instruction filename and discovery mechanism expected by the AI coding
tool. When the pack is stored under `.agents/`, a small project-root entry file
can delegate to it:

```markdown
# Project Agent Instructions

Read and follow `.agents/AGENTS.md`.
Treat paths referenced by that file as relative to `.agents/`.
Read `PROJECT-AGENT-PROFILE.md` before planning or acting when it exists.
```

If the project already has agent instructions, integrate this delegation
without deleting project-specific constraints. Higher-priority platform and
user instructions continue to apply.

### 3. Create the project profile

Copy
[`templates/PROJECT-AGENT-PROFILE.md`](templates/PROJECT-AGENT-PROFILE.md)
to the adopting repository root as `PROJECT-AGENT-PROFILE.md`, then replace its
prompts with concise, sourced, current facts.

At minimum, record:

- the profile owner, adopted pack version, evidence sources, and verification
  date;
- project purpose, critical journeys, and unacceptable outcomes;
- verified install, test, lint, typecheck, build, and security commands;
- architecture, contracts, state ownership, and important invariants;
- authentication, authorization, tenant, secret, privacy, and data boundaries;
- runtime dependencies, environments, observability, recovery, and release
  expectations;
- allowed and separately authorized actions by task mode; and
- project-specific definition of done.

Example:

```markdown
# Project Agent Profile

## Profile Metadata

- Project/profile owner: Platform Team
- Governance pack version adopted: `<governance-manifest.json pack_version>`
- `last_verified_at`: `<YYYY-MM-DD and checked environment>`
- `sources`: `composer.json`, `package.json`, `.github/workflows/ci.yml`
- `adopted_overlays`: `laravel-react-inertia`
- Known stale or unverified sections: latest production restore rehearsal

## Verified Development Commands

| Purpose | Command | Working directory | Expected result | Source | Last verified |
|---|---|---|---|---|---|
| Unit tests | `php artisan test` | project root | Tests pass | `composer.json` | `<YYYY-MM-DD>` |
| Typecheck | `npm run types` | project root | Exit code 0 | `package.json` | `<YYYY-MM-DD>` |
| Build | `npm run build` | project root | Build succeeds | `package.json` | `<YYYY-MM-DD>` |
```

Use the project's real commands and evidence. Do not copy the example values
unless they are true for that repository.

Keep secrets, tokens, credentials, private endpoints, and personal data out of
the profile. Treat unsourced, stale, placeholder, or contradictory entries as
unknown rather than permission or current fact.

### 4. Adopt an optional overlay

An overlay supplies fallback preferences for a specific project family. It is
not activated by detecting a framework automatically.

The included Laravel, React, Inertia, and TypeScript overlay is enabled by this
profile entry:

```markdown
- `adopted_overlays`: `laravel-react-inertia`
```

Overlay precedence is:

1. repository code, lockfiles, configuration, tests, and working behavior;
2. sourced and current project-profile facts; and
3. overlay fallback preferences.

An overlay cannot lower risk, remove a required rule, grant action authority,
or force a dependency or architecture migration.

### 5. Use the agent normally

Ask for the task and desired outcome in plain language. Clear scope and action
verbs help the agent select the correct mode:

```text
Review the authorization flow and report findings. Do not change files.
```

```text
Fix the queue retry bug, preserve the public API, and add a regression test.
```

```text
Design a migration plan only; do not edit the repository or run it.
```

```text
Deploy version 2.4.1 to the named staging environment.
```

The final example is an `OPERATE` request. The agent must still resolve the
target, apply the composed confirmation level, respect platform approvals, and
stop if the requested authority is incomplete.

## How The Agent Uses The Pack

For a governed engineering request, the agent should:

1. Read [`GEMINI.md`](GEMINI.md).
2. Read the adopting project's `PROJECT-AGENT-PROFILE.md`, when present.
3. Select exactly one current task mode.
4. Route through
   [`governance-manifest.json`](governance-manifest.json), using
   [`rules/governance-router.md`](rules/governance-router.md) as the readable
   view.
5. Apply the union of matching rules.
6. Load one lead skill when possible and only bounded supporting skills.
7. Inspect the relevant repository evidence before acting.
8. Apply [`rules/agent-operation-safety.md`](rules/agent-operation-safety.md)
   before code execution or state-changing tools.
9. Verify claims proportionally to consequence.
10. Deliver task outcome, release readiness, and external-action status
    separately.

If the task changes from review or design into implementation, or from
implementation into deployment, the agent must reclassify and reroute rather
than inheriting authority from the previous mode.

## Modify Or Extend The Pack

Use [`governance-manifest.json`](governance-manifest.json) as the authoritative
inventory. Keep generated router sections, schemas, catalogs, and tests aligned
with it.

Common extension points:

- add or refine a routing signal in the manifest;
- add a rule under `rules/` and register it in the manifest;
- add a narrowly scoped skill under `skills/` and register it;
- add an optional project overlay under `overlays/`;
- extend exact routing and raw evaluation cases; or
- add capability cases and non-compensatory failure criteria.

When the manifest changes, regenerate the readable router:

```powershell
./scripts/generate-governance-router.ps1
```

Install the pinned schema-validation dependencies from
[`requirements-governance.txt`](requirements-governance.txt) in an isolated
Python environment. Ensure that environment's `python` command is active, then
run the aggregate:

```powershell
python -m pip install ``
  --disable-pip-version-check ``
  --no-input ``
  --only-binary=:all: ``
  --requirement requirements-governance.txt
./scripts/test-governance.ps1
```

On systems where PowerShell is launched explicitly:

```text
pwsh ./scripts/test-governance.ps1
```

The aggregate checks:

- executable JSON Schema validation and malformed-input rejection;
- generated-router parity;
- manifest, schema, inventory, and reference integrity;
- exact routing scenarios and raw routing coverage;
- routing scorer bypasses and process exit contracts;
- capability catalog coverage and scorer behavior; and
- governance-validator mutation tests.

The CI workflow runs the same aggregate on Windows and Linux.

## Evaluation Artifacts

The repository contains two complementary evaluation layers:

- [`tests/routing-evaluations.json`](tests/routing-evaluations.json) checks
  whether an agent selects the expected mode, signals, risk, confirmation, and
  skills for raw requests.
- [`tests/capability-evaluations.json`](tests/capability-evaluations.json)
  defines broader engineering capability cases and scoring criteria.

Use
[`tests/routing-evaluation-run.template.json`](tests/routing-evaluation-run.template.json)
and
[`templates/CAPABILITY-EVALUATION-RUN.json`](templates/CAPABILITY-EVALUATION-RUN.json)
as run-record starting points.

The bundled scorers validate record structure, declared reviewer separation,
criterion coverage, automatic failures, and artifact hashes. They do not
authenticate reviewer identity or independently establish that cited evidence
is substantively relevant. Treat results as reviewer-attested unless an
external review system supplies that assurance.

## Troubleshooting

### The agent does not read the pack

Confirm that the AI tool discovered the project-root instruction file and that
the file points to the actual pack location. Verify that relative paths resolve
from the pack directory.

### The project profile is ignored

Confirm that the file is named exactly `PROJECT-AGENT-PROFILE.md`, is in the
adopting repository root, and is referenced by the project's entry
instructions.

### An overlay is not active

Use the exact overlay identifier from `governance-manifest.json` in the
profile's `adopted_overlays` field. Framework detection alone does not activate
an overlay.

### Generated-router parity fails

Update the manifest first, then run:

```powershell
./scripts/generate-governance-router.ps1
```

Review the generated diff and rerun the aggregate.

### Schema validation uses the wrong packages

Activate the isolated Python environment containing the exact versions from
`requirements-governance.txt`, then rerun the aggregate.

### The agent applies too much ceremony

Check the selected risk and signals. Trivial and bounded Standard work should
use proportional evidence rather than unnecessary architecture, threat-model,
benchmark, or rollout artifacts.

## Safety And Scope

This pack improves consistency and makes important decisions testable. It does
not:

- grant permission to modify external or production systems;
- replace qualified legal, compliance, privacy, or security review;
- prove that an application is correct or secure;
- make a local result equivalent to production evidence; or
- make an artifact production-ready merely because governance validation
  passes.

Use current repository evidence, human review, target-environment verification,
and operational controls appropriate to the system's actual consequences.
