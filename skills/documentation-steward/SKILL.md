---
name: documentation-steward
description: Create, update, review, or retire durable technical documentation. Use for README/onboarding, API/reference docs, architecture maps, ADRs, runbooks, deployment/operations guides, code comments, examples, changelogs, migration guides, or documentation drift after code/config changes. Do not create extra docs when an existing source of truth should be updated.
---

# Documentation Steward

Keep technical knowledge accurate, findable, task-oriented, and owned. Treat
documentation as an interface that must match the running system.

## 1. Identify Audience And Source Of Truth

Name the reader, task/decision, prerequisite knowledge, urgency, and authoritative
source. Search existing docs, code, config, tests, schemas, generated reference,
ADRs, and runbooks before adding a file. Choose one canonical location and link
rather than duplicate.

For a code/config change, map affected documentation: setup, commands,
configuration, API/schema, examples, architecture, operations, troubleshooting,
migration/deprecation, and security/privacy expectations.

## 2. Choose The Right Artifact

- README/onboarding: first successful path and verified prerequisites.
- Task guide: goal-oriented steps, checks, failure recovery, and next action.
- Reference/API: complete stable facts, types, defaults, limits, errors, and versions.
- ADR: context, options, decision, consequences, and reversal/supersession.
- Architecture map: ownership, boundaries, dependencies, data/runtime flow.
- Runbook: symptoms, impact, safe diagnostics, mitigation, escalation, recovery.
- Code comment: why, invariant, non-obvious constraint, or external contract—not a
  narration of syntax.

Use the project's existing documentation structure and vocabulary.

## 3. Ground Every Instruction

Verify commands, paths, flags, versions, environment assumptions, links, sample
payloads, outputs, screenshots, and failure behavior against code or tools. Mark
environment-specific or unverified material. Never place secrets, private
endpoints, PII, or unsafe production commands in examples.

Write task-first headings, short steps, meaningful examples, expected results,
and recovery guidance. Use diagrams only when relationships are materially
clearer than prose.

## 4. Design For Evolution

Assign an owner or authoritative generator/source. Prefer generated reference
when it can be deterministically tied to code, but review generated readability.
Add applicable link checks, doctests, schema/example tests, command smoke tests,
or CI freshness checks.

Update or retire stale docs in the same change. For deprecation, preserve a clear
migration destination and timeline. Mark superseded ADRs rather than rewriting
history.

## 5. Review From The Reader's Path

Follow the instructions from a clean or representative environment when risk
justifies it. Check findability, missing prerequisites, copy-paste safety,
accessibility, localization implications, platform differences, and whether the
reader can diagnose common failures without tribal knowledge.

## Delivery Contribution

Add documentation created/updated/retired, facts and commands verified, audience,
remaining stale areas, and ownership to the unified delivery record in
`GEMINI.md`.

## Hard Rules

- Do not document behavior that code/config/tests do not support.
- Do not create a second source of truth for convenience.
- No secret, PII, destructive default, or unsafe production shortcut in examples.
- Documentation is incomplete when the target reader cannot verify success or recover.

