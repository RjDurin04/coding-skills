---
name: interaction-and-motion-designer
description: "Use when motion, gesture, transition behavior, direct manipulation, or temporal feedback is itself a material interface decision. Not for ordinary static layout, incidental hover or focus styling, generic frontend work with a minor animation, or visual art direction without temporal behavior."
---

# Interaction And Motion Designer

Design how state changes over time without making animation the owner of state,
meaning, or access.

## 1. Start With The Interaction Contract

Apply `rules/interface-and-accessibility-gate.md`. Identify the trigger,
authoritative before/after state, user intent, consequence, input modes,
interruptions, and feedback that must remain perceivable without motion.

For each proposed motion, name its purpose:

- preserve spatial or object continuity;
- show causality or state change;
- direct attention to relevant feedback;
- reveal hierarchy or sequence;
- support direct manipulation;
- explain system latency without inventing progress;
- add expression after task and access needs are satisfied.

If the purpose is unclear or static feedback is clearer, omit the animation.
Frequency, task criticality, content density, device capability, and user
preference should reduce or remove intensity.

## 2. Specify Temporal Behavior

Define the complete state transition, not just an entrance effect:

- trigger and preconditions;
- source and target state;
- property or spatial relationship that changes;
- focus, semantics, announcements, and input availability during the change;
- cancellation, reversal, repeated input, stale completion, and unmount behavior;
- failure, timeout, background-tab, resize, orientation, and preference changes;
- full-motion, reduced-motion, and no-animation outcomes;
- evidence that would establish correctness and acceptable performance.

User input, failure, cancellation, permission changes, and authoritative data
updates outrank passive animation. New intent replaces obsolete transitions;
do not queue stale visual states. Focus placement and domain-state commits must
not wait for animation callbacks.

Read [references/interaction-patterns.md](references/interaction-patterns.md)
for direct manipulation, gestures, overlays, progress, optimistic feedback, and
scroll behavior. Read
[references/motion-engineering.md](references/motion-engineering.md) when
choosing an implementation mechanism or verifying runtime behavior.

## 3. Make Alternatives Equivalent

Reduced motion is a designed path, not a blanket `transition: none` patch. It
must preserve causality, hierarchy, completion, error, progress, focus, and
control. Replace spatial travel, parallax, looping, zoom, and staged delay with
immediate state, restrained fades, static grouping, text, or another perceivable
cue appropriate to the adopted target.

Gestures, hover, drag, and scroll position cannot be the only way to discover or
perform an operation. Provide keyboard, pointer, touch, switch, or explicit
control alternatives as applicable. Use logical rather than culturally assumed
directions.

## 4. Fit The Existing Runtime

Inspect current libraries, tokens, browser or platform support, component
lifecycle, SSR/hydration boundaries, and performance evidence. Prefer the
smallest incumbent mechanism that owns the required behavior. One engine should
own a property and lifecycle; mixing engines is acceptable only across explicit
non-overlapping boundaries. When multiple engines are established, choose the
one already owning the affected surface; otherwise compare lifecycle fit,
smallest code/bundle change, support, testability, and maintenance, name one
default owner, and leave the other unused. An exception needs a concrete
capability gap plus disjoint element/property/lifecycle ownership and evidence;
installation alone is not a reason to mix.

Durations, easing, distances, spring values, frame budgets, and latency targets
come from an adopted system or measured product context. Otherwise label them
`CANDIDATE` with the environment and validation plan. "Only transform and
opacity" is a useful performance heuristic, not a universal ban; measure the
actual property and workload.

When no performance target exists, capture the current no-motion or incumbent
baseline and a representative before/after trace. A candidate may proceed only
with explicit owner acceptance and no observed correctness, input, cleanup, or
material baseline regression; it cannot support a general performance-pass or
readiness claim until a target is adopted.

## 5. Verify The Latest State Wins

Use runtime evidence for rapid repetition, interruption, reversal, cancellation,
preference changes, hidden/resumed documents, cleanup, and slow devices. Check
keyboard and assistive-technology operation in both motion modes. Profile layout,
paint, compositing, input response, frame distribution, bundle impact, and
resource cleanup only to the extent the claim requires.

Deliver a transition matrix and implementation ownership map. Record the exact
artifact, device/browser or platform, input modes, preference modes, workloads,
and unverified paths. A smooth capture is not evidence that state, focus,
accessibility, or resource behavior is correct.

## Hard Rules

- Animation projects state; it does not authorize or commit state.
- No required meaning, content, or operation may depend on motion or gesture.
- Never animate everything to create perceived quality.
- No universal timing, easing, library, or animated-property prescription.
- Stale animation completion must never overwrite newer user or system state.
