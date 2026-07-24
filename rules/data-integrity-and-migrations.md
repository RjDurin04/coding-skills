---
name: data-integrity-and-migrations
trigger: model_decision
description: Apply to persisted data, schemas, migrations, backfills, transactions, destructive ops, idempotency, and repair.
---

# Data Integrity And Migrations

Persisted state is a public contract.

## Trigger

Schemas, migrations, indexes, constraints, seeders, backfills, imports/exports,
repair scripts; create/update/delete, soft delete, archival, retention, audit,
tenant scope; transactions, queues, retries, idempotency, webhooks, payments,
inventory, permissions, denormalized data; anything that can lose, corrupt,
duplicate, leak, or hide data.

## 1. Classify Data

Name owner/context, sensitivity (public/internal/PII/financial/secret/regulated),
lifecycle (source/cache/derived/audit/ephemeral), retention/deletion expectations,
scope/volume/tenancy, and invariants/constraints. Sensitivity alone does not
determine risk: established bounded handling through an unchanged enforced
boundary may be Standard; new authorization/sensitive boundaries, regulated or
bulk handling, cross-tenant paths, destructive actions, and credible
high-consequence loss/leakage/corruption are Critical.

## 2. Enforce Invariants

Prefer: DB constraints/unique/FK/checks > transactions/isolation > idempotency/
dedupe/locks > app validation/domain checks > tests/monitoring > docs. Important
invariants must be enforced stronger than comments.

## 3. Migration Safety

Default backward compatible: add nullable/new structures first; deploy compatible
code; backfill in bounded batches; dual-write or compatibility-read when needed;
switch reads after verification; remove old schema only after rollback window.

Expand-contract: expand schema -> deploy compatible code -> backfill/verify ->
switch reads/writes -> stop old writes -> contract old schema.

## 4. Backfill/Repair Requirements

Define selection criteria, batch size/order, resume/retry, idempotency, rate/lock
strategy, verification query/checksum, abort criteria, rollback/compensation.
No unbounded all-at-once production-shaped scripts.

## 5. Destructive Ops

Material or difficult-to-recover delete/truncate/overwrite/drop/re-key/
mass-update needs fresh confirmation under
`rules/agent-operation-safety.md`, even when the initial request named the exact
operation. First resolve and show exact target/scope/count, auth/tenant scope,
dry-run/preview, expected effect, audit trail, and a verified backup/restore or
compensation path. Ask immediately before execution and ask again if any
material fact changes.

Scoped disposable local test data with verified isolation and a deterministic
reset/recovery path may proceed under ordinary task authority. It must not share
credentials, storage, or identifiers with valuable or shared data. Production,
shared, user, regulated, or uncertain data is never covered by this exemption.

## 6. Checks

Use relevant migration up/down or forward-only rationale; constraint/uniqueness;
transaction rollback; cross-tenant leakage; idempotent retry; representative
backfill verification; query plan/index check for large tables.

## Delivery Contribution

Add material data touched, protected invariants, migration/backfill/recovery
decisions, checks, gaps, and risks to the unified delivery record in `GEMINI.md`.

## Hard Rules

- No material or difficult-to-recover destructive data op without fresh
  confirmation immediately before execution.
- No schema change without compatibility and recovery thinking.
- No multi-step state change without transaction/idempotency/compensation analysis.
- No scoped data access without server-side scope enforcement.
