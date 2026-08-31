# Interface Verification Matrix

Select the smallest set that can falsify material implementation claims.

## Contract And State

- characterize preserved route, data, action, cache, analytics, authorization,
  validation, serialization, and error behavior before changing it;
- test loading, empty, partial, stale, success, busy, invalid, denied, offline,
  conflict, timeout, cancellation, failure, recovery, and repeated action where
  applicable;
- test slow, malformed, duplicated, out-of-order, and superseded responses;
- verify cleanup across unmount, route change, remount, background/foreground,
  and preference changes.

## Interaction And Accessibility

- complete the primary journey with keyboard and relevant alternate inputs;
- inspect semantics, names, relationships, order, visible focus, movement,
  containment, restoration, announcements, errors, and status;
- check zoom/reflow, text spacing, orientation, themes, forced colors, non-color
  cues, reduced motion, media alternatives, and timing controls under the adopted
  target;
- use named screen-reader/browser or native pairings for claims that require
  them; automated scans remain supporting evidence.

## Responsive And Content Stress

Render representative states with:

- narrow and wide containers plus the actual failure points between them;
- portrait/landscape and virtual keyboard where applicable;
- short, long, localized, bidirectional, unbroken, missing, and user-generated
  content;
- large values, deep lists, sparse data, dense data, and media failure;
- touch, coarse pointer, precise pointer, hover absence, and high zoom.

Check source/reading order, clipping, overlap, obscured controls, scroll traps,
sticky regions, target reachability, and task priority—not just screenshot fit.

## Visual Fidelity

Compare the exact artifact with the approved reference at its documented
viewport/content/theme, then capture deliberate responsive and state adaptations.
Classify differences as defects, approved adaptations, contract-preserving
deviations, or unknowns requiring design input. Image diff thresholds are
project-owned candidates unless calibrated; a zero diff can still hide broken
interaction or semantics.

## Performance And Resource Behavior

Measure only accepted targets or label proposals `CANDIDATE`. Depending on the
surface, inspect bundle and route cost, fonts/images, layout shift, input
response, render counts, DOM size, list/windowing behavior, frame distribution,
memory, retained listeners/controllers, and network/cache behavior using a
representative production build and workload.

## Static And Build Evidence

Use the repository's focused tests, type checks, lint/format checks, production
build, dependency/lockfile review, and browser/device matrix. Passing one class
does not imply another: a build does not establish accessibility, a visual diff
does not establish contracts, and an automated accessibility scan does not
establish task completion.

## Delivery Record

Report artifact/revision, changed files and contracts, test commands and result,
browsers/devices/platforms, viewports/containers, content/state fixtures,
accessibility target and pairings, performance workload, deviations, unverified
paths, and residual risk. Do not generalize beyond observed coverage.
