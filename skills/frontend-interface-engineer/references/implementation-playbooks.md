# Interface Implementation Playbooks

Read only the sections matching the implementation.

## Semantic Structure And Components

Start with the document/task model: landmarks, headings, navigation, lists,
tables, forms, controls, status, and content order. Use native elements when
their semantics and behavior fit. An established accessible component primitive
is preferable to reimplementing a standards-heavy pattern.

Component boundaries should own cohesive behavior, state, semantics, styling,
and tests. Avoid both one component per visual box and a monolith that mixes data
fetching, business rules, navigation, presentation, and transient effects.
Expose composition and semantic variants instead of raw internal selectors or a
large boolean matrix.

## Layout And Responsive Behavior

- Use grid for two-dimensional relationships and flex for one-dimensional flow;
  prefer intrinsic sizing and content constraints over viewport guessing.
- Let components respond to their container when reuse contexts differ; use
  viewport queries for genuine viewport/environment changes.
- Preserve source order. Avoid CSS reordering that creates a different keyboard
  or reading sequence.
- Ensure children can shrink and wrap; handle long words, code, URLs, large
  numbers, and translated text.
- Test immediately around actual layout failure points, not only named device
  presets.
- Reconsider priority, disclosure, navigation, tables, charts, filters, and
  actions on narrow surfaces. Stacking every desktop region is not a strategy.
- Account for zoom/reflow, safe areas, browser chrome, virtual keyboards,
  orientation, coarse pointers, hover absence, print, and embedded containers
  where relevant.

## Forms And Mutations

Use server validation as authoritative while providing timely client guidance.
Keep labels, instructions, constraints, error associations, required state, and
input purpose explicit. Preserve entered data on recoverable failure.

Model untouched, editing, valid, invalid, submitting, succeeded, failed,
conflicted, expired, denied, and offline behavior as applicable. Prevent
duplicate submission without trapping recovery. Optimistic feedback must be
reversible and cannot claim authoritative success early. Route sensitive fields,
errors, analytics, and assistive announcements through the same privacy boundary.

## Data-Heavy Interfaces

Preserve definitions, units, freshness, completeness, scope, permissions,
missing values, and uncertainty. Use semantic tables for comparison unless a
true interactive grid contract is required. Large collections need bounded DOM
and data work, stable identity, focus-safe virtualization, pagination or windowing
that preserves task continuity, and accessible navigation.

Filters and saved views need explicit state, share/reset behavior, empty versus
filtered-empty distinction, async cancellation, URL/history ownership where
appropriate, and server-enforced scope. Charts need accessible data/summary paths
and cannot be the sole source of exact values or status.

## Media And Assets

- Use real approved assets and source-backed text alternatives.
- Reserve intrinsic geometry to prevent layout shift.
- Use existing CDN/image transformations, responsive sources, formats,
  priorities, lazy loading, and caching contracts; do not invent URL variants.
- Handle missing, slow, failed, single, multiple, portrait, landscape, and user-
  generated media.
- Preserve crop focal points; keep zoom and gallery controls operable without
  gesture or hover.
- Do not generate factual product imagery, logos, or claims without authority.

## SSR, Hydration, And Client Boundaries

Server and initial client rendering must agree for locale, theme, time, random
values, feature flags, permissions, data, and media. Use established client-only
boundaries for browser APIs. Avoid hiding hydration errors or moving entire
routes client-side to bypass them.

Subscriptions, observers, timers, pending requests, animation controllers,
event listeners, portals, and object URLs need idempotent cleanup. Handle route
changes, remounts, suspense/loading boundaries, error boundaries, background
tabs, and preference changes as the framework requires.

## Native And Hybrid Surfaces

Use platform navigation, controls, type scaling, safe areas, keyboard/input,
permissions, focus/accessibility, lifecycle, and back behavior when they reduce
error and learning cost. Share product intent and semantic tokens where useful,
but do not reproduce web DOM behavior in a native runtime. Test actual device
and OS behavior when making platform claims.
