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
and invariants/constraints.

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

Delete/truncate/overwrite/drop/re-key/mass-update needs explicit approval unless
the user requested that exact action. Before doing it verify backup/restore,
constrained scope, dry-run/count, auth/tenant scope, and audit/change log.

## 6. Checks

Use relevant migration up/down or forward-only rationale; constraint/uniqueness;
transaction rollback; cross-tenant leakage; idempotent retry; representative
backfill verification; query plan/index check for large tables.

## Delivery Contribution

Add material data touched, protected invariants, migration/backfill/recovery
decisions, checks, gaps, and risks to the unified delivery record in `GEMINI.md`.

## Hard Rules

- No destructive data op without explicit approval.
- No schema change without compatibility and recovery thinking.
- No multi-step state change without transaction/idempotency/compensation analysis.
- No scoped data access without server-side scope enforcement.
