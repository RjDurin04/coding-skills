# Motion Engineering Playbook

Read this when implementing or reviewing runtime motion.

## Choose The Smallest Owner

| Need | Usually start with | Escalate when |
|---|---|---|
| Simple state style | CSS transition/keyframes | interruption, sequencing, or lifecycle needs exceed CSS ownership |
| Imperative browser timeline | Web Animations API | framework orchestration or advanced sequencing has an incumbent owner |
| Component enter/layout state | Existing framework motion library | the project already standardizes another mechanism |
| Complex timeline/scroll/media | Existing specialist engine | the effect has a measured product purpose and bounded lifecycle |
| Direct canvas/WebGL/native | Platform-native loop/tooling | the platform contract and profiling support it |

This table is a starting point, not a library mandate. Check installed versions,
project usage, SSR behavior, tree shaking, platform support, and lifecycle
ownership before choosing.

## Runtime Invariants

- Domain state is authoritative; animation state is derived and disposable.
- A generation, abort signal, or equivalent prevents stale callbacks from
  mutating a newer state.
- Cancel and cleanup are idempotent on unmount, route change, preference change,
  hidden document, and replaced intent.
- One owner controls a given element/property lifecycle.
- Input and semantics remain available while presentation changes.
- A failed animation leaves the correct final state, not a blank or inert UI.

## Performance Reasoning

Prefer properties and mechanisms that avoid unnecessary layout and paint, but
profile rather than reciting a property whitelist. Consider:

- element count, area, layers, overdraw, filters, shadows, masks, and text;
- layout reads/writes and observer callbacks;
- main-thread work, long tasks, input response, frame distribution, and refresh
  rate;
- image decode, font loading, hydration, route transitions, and concurrent data
  updates;
- memory, retained nodes, listeners, timelines, requestAnimationFrame loops,
  timers, and GPU resources;
- production bundle and initialization cost.

Record device, browser/platform, power mode, refresh rate, artifact, script,
sample duration, workload, and accepted target. Average frame rate alone can
hide severe tail jank.

## Reduced-Motion Implementation

Resolve the user preference through the project's supported mechanism and react
to runtime changes when the platform exposes them. Central tokens can map full
motion to reduced behavior, but components still need semantic fallbacks for
travel, scale, parallax, loops, and staged content.

Test the preference set before load and changed while an effect runs. Check that
the reduced path:

- renders all content and final layout;
- preserves focus and interaction order;
- stops continuous or vestibular effects;
- communicates progress, hierarchy, and completion through stable cues;
- releases the same resources as full motion.

## Verification Matrix

Select material cases:

- open-close-open and show-hide-show;
- rapid repeated input and opposite-direction input;
- user interruption during programmatic motion;
- stale async completion and out-of-order data;
- failure, cancellation, timeout, and permission change;
- resize, zoom, orientation, locale direction, and content expansion;
- background/foreground, route change, unmount/remount, and preference change;
- slow device, large list, concurrent media, and production bundle;
- keyboard, touch, pointer, screen reader, and reduced/no-motion paths.

Rendered recordings support visual review. Automated state tests, accessibility
inspection, traces, and resource evidence support behavioral claims.
