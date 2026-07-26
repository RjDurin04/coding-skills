---
name: interface-and-accessibility-gate
trigger: model_decision
description: Apply when a user-facing interaction, workflow, content structure, or accessibility behavior changes.
---

# Interface And Accessibility Gate

User interfaces must remain understandable and operable across the input,
content, viewport, language, and assistive-technology states relevant to their
users.

## 1. Resolve The Applicable Target

Discover the project's contractual, regulatory, platform, and product
accessibility target. For new web work with no adopted target, use WCAG 2.2 AA
as a provisional engineering baseline, record that it is not an adopted
contractual or compliance claim, and surface adoption to the responsible
owner. Intent or automated checks alone never establish compliance.

## 2. Preserve Interaction Semantics

- Use semantic structure and meaningful accessible names, labels,
  instructions, and error associations.
- Support keyboard operation, logical and visible focus, focus restoration,
  and focus containment where an interaction requires it.
- Announce relevant dynamic status and validation changes without duplicating
  or leaking sensitive content.
- Make unavailable actions and consequential effects understandable; keep
  server-side authorization and validation authoritative.

## 3. Design For Perception And Variation

- Meet the adopted contrast, non-color cue, resizing, zoom, reflow,
  orientation, motion, media-alternative, timing, and pointer-target
  requirements that apply.
- Check narrow and wide layouts, long and localized content, bidirectional
  text where supported, loading/empty/error/permission states, and recovery
  from user mistakes.
- Do not infer usability or accessibility from a polished screenshot.

## 4. Verify With Mixed Evidence

Use the smallest relevant combination of automated checks, keyboard
inspection, screen-reader testing, responsive inspection, and usability
evidence. Record the target, environments and states checked, defects found,
and important coverage gaps.

## Material Accessibility Release Blocker

Do not mark a material or critical user workflow ready for release while an
unresolved accessibility defect prevents completion under the applicable
target, blocks required keyboard or assistive-technology operation, or makes a
consequential action, status, instruction, or error imperceptible. Missing
evidence for a material accessibility claim remains `UNVERIFIED`; it is not a
pass.

## Delivery Contribution

Add only the resolved target, material interaction decisions, checks, blockers,
and unverified states to the unified delivery record in `GEMINI.md`.
