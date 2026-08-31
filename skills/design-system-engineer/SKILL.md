---
name: design-system-engineer
description: "Use when work creates or changes reusable interface tokens, components, patterns, libraries, design-to-code contracts, contribution rules, versioning, or migration across multiple surfaces. Not for a one-off screen, isolated CSS cleanup, or merely consuming an existing component library."
---

# Design System Engineer

Create a reusable contract only when shared invariants and real consumers justify
the ownership, migration, and governance cost.

## 1. Establish System Pressure

Apply `rules/interface-and-accessibility-gate.md`. Inventory actual products,
platforms, frameworks, versions, themes, density modes, components, tokens,
overrides, consumers, owners, and known exceptions. Trace current behavior and
adoption before proposing a replacement.

Name the repeated problem and stable invariant. Compare:

- preserve or document the incumbent system;
- extend it locally or add a compatibility layer;
- consolidate a repeated contract;
- replace a fundamentally wrong model through a staged migration.

Do not centralize visual resemblance when products have different behavior,
platform semantics, release cadence, or ownership. Do not create a library with
no accountable owner or consumer adoption path.

## 2. Define The Contract Layers

Keep distinct ownership for:

- reference primitives such as raw scales and palettes;
- semantic tokens expressing product roles;
- component contracts expressing structure, state, behavior, and composition;
- patterns combining components around a task;
- templates or examples that demonstrate use without becoming hidden APIs.

For a component specify public anatomy, required and optional content, state
model, events, controlled/uncontrolled ownership where relevant, composition,
semantics, keyboard and focus behavior, responsive and localization behavior,
themes/density/motion, failure behavior, and supported escape hatches.

Prefer composition and stable behavioral roles over a matrix of style booleans.
Product data and business rules remain with product owners. Platform-specific
implementations may share a behavioral contract without forcing one runtime.

Read [references/system-contracts.md](references/system-contracts.md) for token,
component, theming, density, documentation, and verification decisions. Read
[references/governance-and-adoption.md](references/governance-and-adoption.md)
for contribution, versioning, deprecation, migration, and cross-team adoption.

## 3. Encode Variation And Accessibility

Accessibility and interaction states are public component behavior, not consumer
aftercare. Each supported combination must define semantics, focus, input,
announcements, contrast, non-color cues, text resizing/reflow, motion preference,
long/localized content, and bidirectionality where applicable.

Theme, density, platform, and brand are independent axes unless evidence shows
they must be coupled. Compact density cannot shrink text or controls below the
adopted target. Dark mode is not mechanical inversion. Product exceptions use
named semantic extension points, not private selector or internal token leakage.

## 4. Plan Evolution Before Adoption

Define accountable maintainers, decision rights, support matrix, contribution
requirements, artifact identity, version policy, change classification,
deprecation, migration ownership, rollback, and retirement evidence. A schedule
alone is not a migration plan.

Use additive aliases, adapters, or parallel implementations only when they
reduce real migration risk. Every compatibility path needs scope, owner,
consumer inventory, review/removal condition, and evidence. Do not force a
framework upgrade merely to achieve visual centralization.

## 5. Verify Consumers, Not Only The Catalog

Validate schemas and generated artifacts, but also test representative consumers
and exceptions. Use contract and interaction tests, accessibility checks,
theme/density/localization matrices, visual regression, bundle/runtime evidence,
consumer builds, migration pilots, and rollback rehearsal in proportion to risk.

Bind adoption claims to exact versions, platforms, consumers, states, and test
environments. A documentation site, isolated Storybook story, or passing token
build does not prove product integration.

Deliver the system boundary, public contracts, ownership, support matrix,
consumer map, staged migration, evidence gates, exceptions, and unresolved
decisions. Separate candidate adoption from organization-wide readiness.

## Hard Rules

- Inventory and extend before replacing.
- No second token source, component library, or adapter without a concrete
  boundary and lifecycle owner.
- Reuse is earned by shared behavior and ownership, not component count or
  visual similarity.
- Accessibility, states, migration, versioning, and documentation are part of
  the public contract.
- Do not claim adoption from isolated component evidence.
