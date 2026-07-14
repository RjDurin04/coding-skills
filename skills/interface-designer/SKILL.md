---
name: interface-designer
description: UI/UX design protocol for interfaces, flows, and visual systems. Activates on any user-facing design task. Reduces intention-to-action distance through clarity, progressive disclosure, feedback, and inevitability.
---

# Interface Designer

Invoke when designing or reviewing screens, flows, or components. Default to clarity over cleverness. Every decision traces to a user need, business goal, or accessibility requirement.

## Core Principle: Reduce Intention-to-Action Distance

The user's goal should flow into system action with minimal friction, maximal clarity, and—when earned—delight. The best interface feels inevitable.

## H1: Clarity & Cognitive Load

A clear interface answers instantly: Where am I? What can I do? What happens if I do it?

- **Progressive disclosure:** Primary visible; secondary accessible; tertiary hidden. Each flow step asks for minimum info. Novices see simplified UI; power users discover advanced features.
- **Hierarchy:** Visual weight (size, color, position, whitespace, typography) must match semantic importance. Never let marketing banners overpower primary tasks.
- **Gestalt:** Use proximity, similarity, continuity, closure, common fate for implicit organization.

## H2: Affordances & Predictability

- Buttons look pressable; links look tappable; sliders look draggable. Preserve affordances even in minimal aesthetics.
- **Internal consistency:** Predictable across screens/states.
- **External consistency:** Respect platform conventions (iOS, Material, Fluent).
- **Break consistency only** when the convention is flawed, context is unique, or innovation provides overwhelming value.

## H3: Feedback & Statefulness

Every action produces a reaction. Absent feedback destroys trust.
- **Immediate:** >100ms perceptible; >1s feels broken.
- **Informative:** Say what happened and what's next.
- **Proportional:** Minor → subtle; major → prominent.

Design all states:
- **Empty:** Teach, reassure, invite. Never "No data."
- **Loading:** Skeletons > spinners; progress bars > indeterminate when duration is predictable.
- **Error:** What happened, why, and what to do next—plain language, no blame.
- **Partial:** Some data loaded, some didn't.

## H4: Error Prevention

Great designers keep error messages rare.
- **Architectural:** Constraints prevent invalid input at source (date pickers, not free-text).
- **Interface:** Disable buttons when prerequisites unmet. Show requirements before typing. Inline validation > post-submit errors.
- **Contextual:** Add friction for irreversible actions. Friction is a feature here.

## H5: Accessibility Baseline

Design for extremes; the middle follows.
- WCAG 2.1 AA minimum. Aim higher.
- Touch targets: 44×44pt (iOS), 48×48dp (Android).
- High contrast, large targets, screen-reader support benefit everyone (sunlight, coffee hands, aging eyes).

## H6: Fitts's Law & Physical Reality

- Large, proximate targets for related actions.
- Screen edges/corners = infinite in one dimension.
- Respect thumb zones, reachability, environmental context (sunlight, noise, motion).

## H7: Temporal & Memory

- Working memory ≈ 4 chunks. Every element competes.
- Minimize decisions in checkout/high-stakes flows (decision fatigue).
- Users remember peaks and endings. Design both deliberately.
- **Motion semantics:** Right = forward; down = dismissal. Consistency builds spatial understanding.

## H8: Typography, Color, Spacing

- **Measure:** 45–75 chars/line. Leading 1.4–1.6×.
- **Color:** Red=danger; green=success; blue=trust/links. Contrast 4.5:1 normal, 3:1 large. Respect cultural associations.
- **Layout:** 8-point grid. Whitespace is active hierarchy.
- Pair icons with labels when recognition is uncertain.

## H9: Interaction & Motion

- **Micro-interactions:** Single-task moments. Feedback, error prevention, brand.
- **Transitions:** No abrupt state changes. Orient users in information space.
- **Easing:** Ease-out = responsive; ease-in = deliberate; ease-in-out = natural.
- **Duration:** Micro 100–300ms; transitions 300–500ms. >1s = sluggish.
- **Purposeful:** Every animation orients, feeds back, or reveals hierarchy. If removal doesn't reduce clarity, it was unnecessary.

## H10: Systems Thinking

- Products are ecosystems of flows, states, edge cases, dependencies.
- **Tokens:** Abstract colors, type, spacing, radii from components.
- **Components:** Flexible across contexts; constrained for consistency.
- **Documentation:** Undocumented design systems are private languages.
- Map 2nd/3rd-order effects before changes (users, support, analytics, localization, design system).

## H11: Research & Validation

- Every decision is a testable bet: "Changing X will result Y for segment Z, measured by metric M."
- Qualitative = why; quantitative = what/how much. Both required.
- Test 5 users early → catches ~85% of usability problems.
- Say-Do Gap: Combine interviews with analytics.

## H12: Copy as Interface

Poor copy undermines great design.
- **Microcopy:** Clear, concise, actionable. "Save changes" > "Submit."
- **Errors:** What happened, why, next step.
- **Empty states:** Clear path forward.
- **Tone:** Match context (serious for finance; playful for social).

## H13: Ethics

Never manipulate.
- **Forbidden:** Roach motel, hidden costs, confirmshaming, forced continuity, deceptive defaults.
- **Addiction:** Infinite scroll / variable rewards may boost metrics but destroy trust.
- **AI transparency:** Explain algorithmic decisions; provide recourse.
- **Framing:** "Don't lose your progress" > "Save your progress."

## H14: Taste & Restraint

Taste separates competent from inevitable design.
- **Context:** Minimal for meditation; expressive for games; dense for pro tools.
- **Restraint:** Remove anything whose absence doesn't degrade goal completion.
- **Timeless > trendy:** Hierarchy, legibility, affordances endure.
- **Details:** 2px misalignments and off easing curves are felt collectively.

## Platform Reference

- **iOS:** Clarity, deference, depth. Nav top; tab bar bottom; San Francisco; modals slide up.
- **Material:** Bold graphics, meaningful motion. FAB primary; nav drawers; elevation hierarchy.
- **Web:** Underlined links; labeled forms; responsive breakpoints.

## Hard Rule (Ship Checklist)

1. Stressed first-time user understands primary action in <3s.
2. All states (empty, loading, error, partial, success) designed, not accidental.
3. Passes WCAG 2.1 AA minimum.
4. Every element traces to user need, business goal, or accessibility—not ego.
5. Removing any element degrades goal completion. If not, remove it.
