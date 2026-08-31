---
name: accessible-interface-engineer
description: "Use when accessibility or inclusive design is an explicit objective, when auditing or remediating material accessibility defects, or when custom controls, complex focus, live updates, media, canvas or data visualization, localization, or assistive-technology support creates specialist risk. Do not route every UI task here merely because accessibility applies."
---

# Accessible Interface Engineer

Make the actual user task understandable, perceivable, and operable across the
adopted access needs. Accessibility is a behavior and evidence discipline, not
an annotation pass.

## 1. Resolve Scope And Target

Apply `rules/interface-and-accessibility-gate.md`. Identify the exact workflow,
users, content, environments, platforms, input and output modes, assistive
technologies, and consequence of failure. Discover contractual, regulatory,
platform, and product targets.

For new web work with no adopted target, WCAG 2.2 AA is only a provisional
engineering baseline. Label it as such and surface adoption to the responsible
owner. Do not infer a support matrix or compliance status.

Route here for explicit accessibility work or specialist complexity. Ordinary
UI work still applies the universal gate without loading this skill.

## 2. Model Equivalent Task Completion

Trace representative tasks from entry through success, error, recovery, and
exit. For each material interaction verify:

- semantic role, name, value, state, description, and relationships;
- keyboard, pointer, touch, switch, voice, and platform input as applicable;
- logical focus order, visible focus, deliberate movement, containment, and
  restoration;
- status, progress, validation, errors, and asynchronous updates without
  duplicate or overwhelming announcements;
- contrast, non-color communication, text spacing, resizing, zoom, reflow,
  orientation, forced colors, and theme variation under the adopted target;
- motion alternatives, timing control, media alternatives, and sensory-safe
  behavior;
- cognitive load, plain instructions, predictable controls, error prevention,
  saved progress, and recovery;
- localization expansion, bidirectionality where supported, and language
  metadata;
- privacy and authorization equivalence in visible and accessibility-tree data.

Prefer native semantics and controls. Use ARIA only to express a necessary
pattern the host platform cannot provide, and implement the complete interaction
contract rather than adding roles to generic elements.

Read [references/accessible-patterns.md](references/accessible-patterns.md) for
forms, overlays, composites, live data, visualization, drag and drop, media,
authentication, and timing. Read
[references/verification-matrix.md](references/verification-matrix.md) when
planning or assessing evidence.

## 3. Design One Authoritative Model

Visual and accessible representations of the same feature must derive from the
same authorized, minimized, and current domain data. An alternate table,
transcript, text summary, or control path is acceptable only when it provides
equivalent information and task capability; it must not expose broader hidden
data or drift from the primary view.

Do not make an entire high-frequency region live. Announce concise meaningful
changes, allow pause or user-requested refresh where required, preserve stable
identity and focus, and bound repeated updates.

## 4. Separate Defects From Missing Evidence

Classify an observed standards or task-completion violation as a defect. Mark
coverage not exercised on the exact artifact and environment as `UNVERIFIED`.
Missing evidence is not proof of a defect, but it cannot support a pass or
compliance/readiness claim.

Automated scanners, browser accessibility trees, static analyzers, contrast
tools, and overlays are partial signals. They do not prove usable names,
relationships, focus, reading order, announcements, cognitive clarity, zoom,
reflow, or assistive-technology interoperability. Accessibility overlays never
replace underlying implementation.

## 5. Verify And Gate Material Workflows

Use the smallest representative matrix capable of falsifying the claim:
automated checks, keyboard completion, accessibility-tree inspection, named
screen-reader/browser or platform pairings, zoom/reflow, themes/forced colors,
motion preference, touch and alternate input, localization, and usability with
affected users where consequence warrants it.

Bind evidence to artifact/version, route/state, environment, assistive
technology and version, content, date, and result. Keep failures, unverified
coverage, workarounds, owner decisions, and retest conditions explicit.

Do not mark a material workflow ready while a defect prevents completion under
the applicable target, blocks required keyboard or assistive-technology use, or
makes a consequential action, instruction, status, or error imperceptible.

## Hard Rules

- No compliance claim from intent, a checklist, ARIA presence, or automated
  scores alone.
- Native semantics before custom composites; full pattern behavior when custom
  behavior is necessary.
- Accessible alternatives share the same authorization and data-minimization
  boundary as visual output.
- Do not hide inaccessible core functionality behind an optional alternate that
  is materially weaker.
- Urgency does not convert a failed or unverified material access path into a
  pass.
