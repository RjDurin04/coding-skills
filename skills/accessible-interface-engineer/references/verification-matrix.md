# Accessibility Verification Matrix

Use this to select evidence proportional to the claim. Do not run every row by
default.

## Evidence Layers

| Layer | Useful for | Does not establish alone |
|---|---|---|
| Source/static review | semantics, labels, obvious ARIA or event defects | rendered order, focus, AT output, visual perception |
| Automated runtime scan | deterministic rules in rendered states | task completion, announcements, cognitive usability, full WCAG conformance |
| Accessibility tree | roles, names, states, relationships, hidden content | keyboard operation or understandable experience |
| Keyboard/manual | reachability, order, focus, activation, recovery | screen-reader speech or touch/switch behavior |
| Screen reader/platform AT | navigation, names, states, announcements, reading | all AT/platform pairings or visual accessibility |
| Zoom/reflow/visual modes | clipping, overlap, focus, contrast, non-color cues | nonvisual task completion |
| User evaluation | real task barriers in the studied population/context | universal conformance or untested workflows |

## Representative Journey Matrix

Select the material combinations:

- first-time and returning user;
- mouse, touch, keyboard, voice, switch, or other supported input;
- screen reader/browser or native platform pairing from the adopted support
  matrix;
- narrow, wide, portrait, landscape, zoom/reflow, text spacing, and text-size
  settings;
- light, dark, high contrast, forced colors, and reduced motion where supported;
- default, long, localized, bidirectional, missing, and user-generated content;
- loading, empty, partial, stale, disconnected, invalid, denied, conflict,
  timeout, failure, recovery, and success states;
- slow updates, frequent updates, media failure, and third-party failure.

Test complete user journeys, not isolated Tab traversal. A user must be able to
understand, operate, verify the result, correct errors, and leave the workflow.

## Screen-Reader Evidence

Use project-supported pairings. If none exist, propose pairings as `CANDIDATE`
with an owner; do not silently declare a universal matrix. Record:

- operating system, browser/app, AT and versions;
- artifact, route, state, data fixture, language, and date;
- commands or navigation modes exercised;
- observed speech/braille output and task result;
- defects, workarounds, and untested combinations.

## Dynamic Content

Use a fake clock or controlled data source where possible. Verify stable focus
and identity, bounded announcements, pause/resume, stale/disconnected status,
error recovery, permission changes, and parity between visual and accessible
representations. Sustained runs should reveal flooding and resource drift.

## Severity And Readiness

Separate:

- **Defect severity** — observed impact on a user/task under the adopted target;
- **Evidence status** — `PASS`, `FAIL`, `UNVERIFIED`, or `N_A` for the exact
  artifact and matrix slice;
- **Release consequence** — whether the defect or missing evidence prevents the
  requested readiness claim.

A missing screen-reader run is not automatically proof of a screen-reader bug.
It is `UNVERIFIED`; it becomes a release evidence blocker when the requested
claim or risk requires that coverage. An observed inability to complete a
material task is a defect and may be a release blocker under the interface gate.

## Completion Record

Report the adopted/provisional target, artifact identity, supported matrix,
journeys and states exercised, automated tools and versions, manual results,
defects, unverified slices, workarounds, owner decisions, and retest conditions.
Never compress this into an unsupported single accessibility score.
