---
name: configuration-and-feature-flags
trigger: model_decision
description: Apply to runtime configuration, environment settings, secrets references, feature flags, rollout controls, experiments, and kill switches.
---

# Configuration And Feature Flags

Configuration is a versioned contract; a flag is temporary control flow, not an
authorization boundary.

## Trigger

Environment variables, config files/services, secrets references, runtime
settings, per-tenant overrides, feature/release/experiment/operations flags,
kill switches, dynamic policy, or configuration-driven rollout.

## 1. Configuration Contract

- Define owner, type/schema, allowed values/range, units, default, requiredness,
  precedence, environment scope, reload behavior, and compatibility.
- Validate at startup or change boundary and fail safely on invalid material
  settings. Do not silently coerce ambiguous values.
- Keep secrets in an approved secret system; configuration should reference,
  not embed or log them. Separate public/client configuration from server-only
  settings.
- Use secure, conservative defaults. Unknown production settings must not
  silently enable exposure, broad access, destructive behavior, or unbounded
  cost.
- Document only accepted numeric settings. Label proposed values `CANDIDATE`
  with an owner and measurement/acceptance path.

## 2. Flag Contract And Lifecycle

Every durable flag needs: type/purpose, owner, created date, affected
scope/tenants, safe default, rollout and rollback semantics, observability,
expiry/review date or removal condition, and cleanup issue/path.

- Release/experiment flags do not replace server-side authorization,
  validation, privacy, tenancy, or data constraints.
- Kill switches must be tested, access-controlled, auditable, fail in the
  intended direction, and have a recovery/re-enable plan.
- Avoid incompatible state written by mixed flag states; define forward/backward
  behavior across workers, clients, queues, and deployments.
- Bound flag combinations and test material on/off, transition, stale-client,
  and failure states. Do not attempt a combinatorial matrix without risk-based
  selection.
- Remove expired/fully rolled-out flags and dead branches. Convert intentionally
  long-lived control into an owned policy/config mechanism when appropriate.

## 3. Change And Rollout

Version/audit material configuration changes, restrict writers, stage by blast
radius, observe accepted success/abort signals, and provide rollback or
roll-forward. A repository config edit uses `IMPLEMENT`; changing a shared
configuration/flag uses `OPERATE` with the confirmation required by
`rules/agent-operation-safety.md`.

Do not assume a flag makes an unsafe migration reversible. Coordinate schema,
data, cache, event, and external-side-effect compatibility under the relevant
domain gates.

## Delivery Contribution

Record material configuration/flag contract changes, defaults, owner/expiry,
rollout/recovery, checks, target environment, and any pending external action.

## Release Blockers

Block `READY` when a material setting is unvalidated or insecure by default; a
flag bypasses authorization/data safety; a kill switch required for safe rollout
is untested; or a temporary flag lacks an owner and removal/review condition.
