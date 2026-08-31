# Interaction Pattern Playbook

Read the sections matching the current temporal interaction.

## Transition Matrix

For every material transition record:

| Field | Question |
|---|---|
| Trigger | What user or system event starts it? |
| Authority | Which state owner decides the result? |
| Purpose | What does time or movement communicate? |
| Full motion | What changes, and for how long under the adopted system? |
| Reduced motion | How is the same meaning and task preserved? |
| Input | What can the user do while it runs? |
| Interruption | What happens on newer intent, failure, or cancellation? |
| Focus/AT | When do focus, semantics, and announcements change? |
| Cleanup | What controllers, listeners, timers, or layers must end? |
| Evidence | Which runtime case could falsify the contract? |

## Overlays, Menus, And Route Changes

- Make semantics and focus active when the interaction state changes, not after
  the entrance completes.
- Close and restore focus from state ownership, not a completion callback.
- Rapid open-close-open must continue from the current presentation toward the
  newest state without unmounting a newly reopened surface.
- Preserve history, route title, reading position, and announcement behavior as
  required by the framework and product contract.
- Reduced motion may use immediate display or restrained opacity when opacity is
  acceptable; it must not add a delayed unusable interval.

## Direct Manipulation And Gestures

- During drag, resize, scrub, reorder, or drawing, visual feedback follows input
  directly; decorative easing belongs after release, if at all.
- Define capture loss, pointer cancellation, multi-touch, escape/cancel,
  boundary, snap, invalid drop, undo, and concurrent-state behavior.
- Do not let a gesture be exclusive. Provide visible controls and keyboard or
  assistive alternatives suitable to the platform.
- Announce the result, not every intermediate coordinate. Preserve access to
  current value, limits, and instructions.
- Momentum and spring behavior are candidates until platform guidance or
  testing supports them.

## Optimistic Feedback And Progress

- Distinguish local intent accepted, request pending, authoritative success,
  partial success, conflict, cancellation, and failure.
- Visual optimism must be reversible and must not claim completion before the
  authoritative boundary confirms it.
- Never fabricate percent progress. Use stage text, an indeterminate treatment,
  or honest elapsed state when no measurable total exists.
- Coalesce frequent updates, announce meaningful stage or terminal changes, and
  prevent notification flooding.
- Terminal failure, cancellation, permission loss, and success appear
  immediately even if a prior interpolation is running.

## Lists, Layout, And Shared Elements

- Preserve object identity across movement. Stable keys and data identity matter
  more than visual morphing.
- Explain insert, remove, reorder, expansion, and collapse without making users
  wait or lose their reading/focus position.
- Layout animation must not hide content, create an inaccessible duplicate, or
  leave the reduced-motion path in an off-screen or sticky intermediate layout.
- A shared-element transition is appropriate only when source and destination
  represent the same conceptual object and responsive layouts have a safe
  fallback.

## Scroll-Linked And Staged Motion

Use scroll-linked motion as progressive enhancement. Content and controls remain
available in document order without the effect. Define behavior for keyboard
navigation, anchors, search/find, fast and reverse scroll, resize, orientation,
history restoration, printing, reduced motion, and failed initialization.

Stagger only when sequence communicates hierarchy or process. Do not delay
large lists, recurring tasks, error recovery, or time-critical information to
create spectacle.

## Feedback And Microinteractions

Microinteractions must expose current state and consequence. Check:

- hover, focus, pressed, selected, disabled, busy, success, and error;
- repeated or double input;
- input-device change;
- latency and failure;
- sound/haptic alternatives and user control where relevant;
- whether celebration is appropriate to context and frequency.

An effect that repeats hundreds of times per day should usually be quieter and
faster than a rare expressive moment.
