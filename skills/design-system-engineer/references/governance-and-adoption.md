# Governance And Adoption

Read this for a shared-system rollout, migration, deprecation, or contribution
model.

## Ownership

Name one accountable system owner and the engineering, design, accessibility,
content/localization, release, and consumer responsibilities appropriate to the
organization. Define support and escalation. Executive sponsorship does not
replace day-to-day ownership.

Each consumer team owns product regression and migration evidence. The system
team owns public contracts, artifacts, documentation, compatibility, and the
conformance kit. Shared responsibility without named decisions becomes no
responsibility.

## Contribution Contract

A material contribution should include:

- verified consumer problem and affected products;
- why an existing primitive, component, pattern, or local solution does not fit;
- proposed public contract and alternatives;
- every supported state/theme/density/platform value;
- accessibility, localization, content, performance, and compatibility impact;
- tests, documentation, migration, version, rollback, and owner.

Use a lightweight path for internal fixes that do not change public behavior.
Do not force architectural ceremony on token-value corrections, but still review
their user-visible and contrast impact.

## Change Classification

Classify by consumer impact, not file type:

- compatible implementation fix with unchanged public behavior;
- visual or token behavior change requiring product review;
- additive public capability;
- deprecated capability with supported replacement;
- breaking behavior/API/token removal;
- security or accessibility correction whose urgency may require an exceptional
  release path without hiding consumer impact.

Semantic Versioning may express compatibility policy but does not prove it.
Verify resolved artifacts, public surface, consumer builds, and migration notes.

## Staged Adoption

1. Inventory consumers and establish baseline behavior/evidence.
2. Ratify the smallest public contract and support matrix.
3. Build conformance tests and one representative implementation.
4. Pilot a typical consumer and a difficult/legacy consumer.
5. Review behavior, accessibility, visual, performance, build, and ownership
   evidence.
6. Expand team by team with rollback and visible progress.
7. Retire compatibility paths only after consumer-exit evidence.

A two-week deadline can produce a candidate, pilot, or plan; do not relabel it
as completed organization-wide adoption.

## Compatibility And Exceptions

An alias, adapter, wrapper, or parallel implementation is justified when it
isolates a real runtime/contract mismatch or reduces migration risk. Record:

- exact consumers and mismatch;
- supported behavior and known divergence;
- owner and review/removal condition;
- tests and observability;
- rollback and failure path.

Do not leave permanent dual sources of truth. Product exceptions use documented
semantic extension points with scope and ownership. Repeated exceptions may
indicate a missing system capability or an abstraction that is too broad.

## Deprecation And Retirement

Announce replacement, compatibility window or evidence-based exit criteria,
consumer inventory, migration tooling/guidance, and support owner. Track actual
use through source/build evidence or approved telemetry when available. A date
alone does not prove consumers migrated.

Remove only after representative product tests pass, known consumers have exited
or accepted the impact, artifacts and docs point to the replacement, and a
recovery path is understood. Destructive cleanup still follows repository and
operation authority.

## Adoption Record

Report exact artifact versions, source/owner, supported platforms, pilot
consumers, test environments, exceptions, failures, unverified combinations,
migration progress, rollback, and next decision. Keep "candidate", "available",
"adopted", and "retired" as distinct lifecycle states.
