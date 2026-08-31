# Interface Review Evidence Matrix

Calibrate review findings and readiness claims against verifiable evidence tiers.

## Evidence Tiers

| Tier | Source / Method | Supported Claims | Limits / Gaps |
|---|---|---|---|
| **Tier 1: Static Source Inspection** | AST parsing, CSS rule analysis, component prop audits, markup review | Structural markup, token usage, basic semantics, aria attribute presence | Does not prove rendered layout, actual contrast, screen-reader behavior, or runtime interaction |
| **Tier 2: Automated Tooling** | Axe, Lighthouse, pa11y, stylelint, TypeScript compiler | Mechanical rule adherence, basic contrast math, missing alt attributes, type safety | Catches ~30-40% of accessibility issues; cannot verify cognitive clarity, logical flow, or complex focus |
| **Tier 3: Rendered Snapshot / Trace** | Multi-viewport browser renders, Playwright/Cypress traces, visual regression captures | Responsive layout integrity, visual hierarchy, element visibility, computed styles | Does not prove real device touch feel, dynamic network latency impact, or assistive tech announcement quality |
| **Tier 4: Interactive / Manual Verification** | Keyboard navigation, VoiceOver/NVDA testing, touch screen interaction, zoom/reflow test (200-400%) | Operable focus flow, modal containment, live announcements, gesture handling, text reflow | Specific to tested browser/screen reader combination; time-intensive |
| **Tier 5: Representative User Testing** | Task-based usability tests with diverse users and access needs | Real-world task success, comprehension, emotional response, error recovery | Sample size limitations; context-specific |

## Review Verification Checklist

- [ ] **Viewports Tested**: 320px (minimum mobile), 375px/390px (standard mobile), 768px (tablet portrait), 1024px (tablet landscape / small laptop), 1440px+ (desktop).
- [ ] **Input Modes Tested**: Physical keyboard only, touch/pointer, mouse hover/click, voice/switch if applicable.
- [ ] **Accessibility Evaluated**: Focus visibility, tab order, dialog containment, accessible names on icon buttons, form error linkage, color contrast ratios (4.5:1 text, 3:1 UI components).
- [ ] **Motion & Theme Variations**: `prefers-reduced-motion: reduce` verified; light/dark themes and forced colors checked if supported.
- [ ] **Content Extremes Tested**: Empty collections, single-item lists, 100+ item lists, very long unbroken strings, localized text expansion (+30%), null/undefined values.
- [ ] **Runtime States Inspected**: Initial skeleton/spinner loading, empty results, partial error with retry, offline / timeout handling, success toast / inline confirmation.
