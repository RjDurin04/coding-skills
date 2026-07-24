---
name: graceful-sunset-steward
description: Use when deprecating, replacing, migrating, disabling, or removing a feature, API, schema, service, dependency, or legacy system. Select a context-appropriate transition pattern, protect consumers and data, and define evidence-based exit criteria without imposing fixed timelines or architectures.
---

# Graceful Sunset Steward

## 1. Establish The Sunset Contract

Inventory known consumers, owners, contracts, traffic, dependencies, stored and
derived data, retention obligations, operational procedures, and recovery
options. Mark unknown consumers or unverifiable usage as risk rather than
assuming absence.

Define:

- replacement or end state;
- compatibility and migration obligations;
- measurable exit criteria;
- decision owner and support path;
- reversible and irreversible steps.

## 2. Select A Transition Pattern

Choose by consumer control, data coupling, reversibility, scale, and operational
capacity. Options include an in-place migration, compatibility adapter,
deprecation window, staged routing, strangler transition, expand-contract
schema change, or a controlled one-time cutover.

Treat every pattern as an option:

- Do not introduce dual writes unless reconciliation, idempotency, and added
  operational complexity are justified.
- Do not force a staged migration when a bounded atomic cutover is safer.
- Derive notice periods and safety windows from contracts, observed usage,
  consequence, and stakeholder needs; do not invent fixed months or days.

## 3. Protect Data And Consumers

Define data mapping, validation, reconciliation, failure recovery, retention,
deletion, legal hold, archive access, and restoration requirements as
applicable. Verify business invariants, not only counts. Test representative
edge cases and rollback or roll-forward paths at the risk level required.

Communicate through channels appropriate to the actual consumers. Provide
working migration guidance, status visibility, and a final removal notice when
external or cross-team users are affected. Leave a redirect, error, tombstone,
or durable decision record only when it will help remaining callers or
operators.

## 4. Execute With Authority

Planning and read-only readiness assessment do not authorize disabling, deleting,
cutting over, or mutating shared systems. Resolve exact targets and obtain the
required authorization and fresh confirmation before an irreversible step.

## Hard Rules

- Do not remove a contract or data silently.
- Do not claim consumers migrated without usage and acceptance evidence.
- Do not let a temporary compatibility path persist without an owner and exit
  condition.
