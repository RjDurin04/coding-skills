---
name: interface-designer
description: Use when designing, implementing, or reviewing a user-facing screen, component, workflow, interaction, or design system. Ground decisions in user goals, local conventions, applicable accessibility requirements, responsive behavior, localization, and evidence rather than universal aesthetic claims.
---

# Interface Designer

## 1. Establish Context

Identify the primary users, tasks, environment, content, device and input modes,
risk of error, business constraints, and existing design system. Preserve local
patterns when they work; deviate only for a concrete usability or accessibility
reason.

Map the main path and relevant loading, empty, partial, success, disabled,
offline, permission-denied, validation, and failure states. Include recovery or
undo for consequential actions when practical.

## 2. Design The Interaction

- Make primary actions and consequences clear without hiding necessary context.
- Use progressive disclosure only when it reduces real complexity.
- Preserve recognizable controls, meaningful labels, and consistent feedback.
- Prevent errors through constraints and early guidance; explain unavailable
  actions instead of silently disabling them.
- Keep server-side authorization and validation authoritative.
- Match density, hierarchy, copy, and feedback to the task and audience rather
  than a universal aesthetic.

## 3. Meet The Applicable Accessibility Target

Apply the target resolved under
`rules/interface-and-accessibility-gate.md`. Do not claim compliance from
intent or automated checks alone.

Verify as relevant:

- semantic structure, accessible names, instructions, and error association;
- keyboard operation, logical focus order, visible focus, focus restoration, and
  modal focus containment;
- screen-reader announcements for dynamic status and errors;
- contrast, non-color cues, text resizing, zoom, reflow, and orientation;
- pointer target size under the adopted standard and platform guidance;
- reduced-motion preferences and operation without motion;
- captions, transcripts, alternatives, and timing controls for media.

## 4. Design For Variation

Test narrow and wide layouts, long and short content, localization expansion,
pluralization, date/number formats, bidirectional text, and right-to-left layout
where supported. Do not assume color meaning, reading direction, gesture,
navigation position, or motion direction is culturally universal.

Protect privacy in previews, errors, analytics, assistive labels, and shared
screens. Avoid deceptive defaults, hidden costs, confirmshaming, forced
continuity, or asymmetrical cancellation.

## 5. Validate With Evidence

Use the smallest useful mix of design review, automated checks, keyboard and
screen-reader testing, responsive inspection, usability observation, analytics,
and experiment data. Treat numeric usability claims, timing thresholds, and
sample-size rules as context-dependent evidence, not universal facts.

Report what was tested, target and viewport/input coverage, defects found, and
unverified states. A polished screenshot is not evidence that the workflow is
usable or accessible.
