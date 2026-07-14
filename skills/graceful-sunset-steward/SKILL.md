---
name: graceful-sunset-steward
description: Use when retiring systems, deprecating APIs, migrating off legacy platforms, or shutting down features. Activates on "let's replace", "migrate from X to Y", "deprecate this endpoint", or EOL planning. Executes the Strangler Fig pattern with data integrity guarantees, compliance-aware archival, and zero-surprise communication to dependents.
---

# Graceful Sunset Steward

## Activation Procedure

Before acting, ask:
1. Is the user asking to remove, replace, migrate, or deprecate something?
2. Will this change make existing code, data, or integrations unreachable?
3. Is there an old system being replaced by a new one?

If ≥1 is YES → engage. Adding a feature or fixing a bug is NOT a sunset task.

## Execution Protocol

### Step 1: Census
Before ANY sunset action, identify: who depends on this, their migration path, what data lives here (PII/financial/audit/ephemeral), and compliance regime. If any unknown → stop and discover.

### Step 2: Choose Sunset Pattern
- **APIs/Services**: Strangler Fig — new alongside old → route traffic (1%→100%) → old read-only → old dark → decommission
- **Endpoints**: Deprecation Ladder — T-6mo header, T-3mo email guide, T-1mo sunset date, T-0 return 410, T+1mo remove code
- **Data**: Expand-Contract — new schema coexists → dual-write + backfill → verify zero diff → read-switch → stop writing old → drop after safety window

### Step 3: Verify Integrity
Before cutover: row counts match, checksums on sampled records, edge cases (nulls/unicode/max-length/soft-deletes), referential integrity, timestamps preserved, business invariants hold. Run in staging with production-shaped data.

### Step 4: Archive & Compliance
Declare: retention requirement per regulation, archive format, access procedure, legal holds, right-to-be-forgotten mechanism.

### Step 5: Communicate
Plan: T-minus announcements, migration docs with working examples, support channel, "lights out" notice, post-sunset FAQ.

### Step 6: Point-of-No-Return Checklist
Before irreversible step: backup verified restorable, rollback rehearsed, all consumers confirmed migrated, zero traffic to old system for N days, legal sign-off, archive accessible, post-sunset contacts identified.

### Step 7: Tombstone
Leave redirect/410/docs explaining what happened. Record ADR for WHY. Set retention clock with automated purge.

## Hard Rule
No big-bang shutdowns. No silent deletions. No "we told them 6 months ago" without proof.