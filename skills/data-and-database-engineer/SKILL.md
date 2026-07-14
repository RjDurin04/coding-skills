---
name: data-and-database-engineer
description: Design or review data models and database behavior. Use for schemas, relationships, constraints, indexes, query plans, transactions, isolation, locking, replication, partitioning, retention, analytical versus transactional workloads, database selection, or persistent-state performance and correctness. Pair with the migration rule for schema rollout and destructive data work.
---

# Data And Database Engineer

Design persisted state from invariants, workload, lifecycle, and failure
semantics rather than from framework defaults.

## 1. Characterize Data And Workload

Name:

- Source of truth, owners, sensitivity, lifecycle, retention, and deletion.
- Entities, relationships, cardinalities, invariants, identity, and history needs.
- Read/write operation mix, access paths, ordering, aggregation, and search.
- Current/peak volume, growth, concurrency, latency, durability, and availability.
- Tenant/scope boundaries and analytical versus transactional use.

Use representative production-shaped evidence when available. Do not choose a
database or schema from labels such as "big data" without workload facts.

## 2. Build The Logical Model

Make invalid durable states hard to represent. Choose keys, relationships,
constraints, uniqueness, checks, nullability, temporal/history representation,
and audit fields deliberately. Normalize to protect invariants; denormalize only
for a measured read/availability need with clear ownership and repair.

Define which invariants belong in database constraints, transactions, domain
logic, or reconciliation. Types alone cannot protect state written by another
process.

## 3. Define Transaction And Concurrency Semantics

Map transaction boundaries and failure points. Choose isolation, locking,
optimistic concurrency, compare-and-swap, idempotency, or serialization based on
actual anomalies to prevent: lost update, dirty/non-repeatable read, write skew,
duplicate effect, phantom, and deadlock.

Keep transactions bounded and avoid network calls while holding database locks
unless the failure model explicitly requires it. Define retry safety and lock
ordering.

## 4. Design Physical Access

For material queries, inspect or predict query plans and row/cardinality shape.
Choose indexes by predicates, joins, ordering, selectivity, write cost, and
storage—not by column popularity. Check N+1 behavior, full scans, deep offsets,
hot keys, connection pools, batch sizes, and materialization.

Use partitioning, replicas, sharding, search stores, caches, or warehouses only
when a named scale/availability/analytics force justifies their consistency and
operational cost. Define replication lag and stale-read tolerance.

## 5. Plan Lifecycle And Verification

Use `rules/data-integrity-and-migrations.md` for expand-contract, backfill,
rollback/compensation, and destructive work. Verify constraints, transaction
rollback, concurrent behavior, query plans/counts, representative volume,
backup/restore, retention/deletion, and cross-tenant scope as applicable.

## Delivery Contribution

Add the workload evidence, model/invariants, transaction and query decisions,
scale assumptions, checks, and unverified data risks to the unified delivery
record in `GEMINI.md`.

## Hard Rules

- Persisted state is a contract across processes and time.
- No index, denormalization, cache, replica, or datastore change without a named
  access, scale, or availability force.
- No multi-step critical state transition without anomaly and recovery analysis.
- No database performance claim without query/workload evidence.

