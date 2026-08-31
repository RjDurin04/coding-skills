# Visual Language Playbook

Read this when a request needs concrete art direction or refinement beyond the
entrypoint contract.

## Direction Contract

Capture only decisions that materially constrain implementation:

1. **Visual authority** — approved comp, brand system, incumbent product, or a
   candidate direction.
2. **Attention sequence** — the order in which content and actions should be
   noticed and understood.
3. **Concept** — one sentence connecting product character to a visual idea.
4. **System** — grid, rhythm, type roles, color roles, surfaces, density,
   imagery, icons, and state treatment.
5. **Variation** — narrow/wide, short/long, theme, localization, media failure,
   and input/focus behavior.
6. **Boundaries** — behavior, content, assets, and conventions that remain
   unchanged.
7. **Evidence** — rendered states and checks that could falsify the direction.

Compare alternatives by task clarity, contextual fit, system coherence,
content resilience, accessibility, implementation fit, and reversibility.
Avoid rankings based on novelty or personal preference alone.

## Composition And Grouping

- Start from information relationships: sequence, containment, comparison,
  dependency, hierarchy, and action proximity.
- Choose a grid that supports the content. Break it only to create intentional
  emphasis or narrative, and restore alignment downstream.
- Use proximity and alignment before borders and cards. A surface should mark a
  real interaction, elevation, grouping, or material change.
- Balance is perceptual, not merely symmetric. Account for text density, image
  weight, color intensity, and negative space.
- Maintain a legible anchor in expressive compositions. Novel layout must not
  make the primary task or reading order ambiguous.
- Treat whitespace as allocated attention. Too little obscures grouping; too
  much separates related information and reduces useful density.

## Typography

Define roles before sizes: display, page title, section heading, body, label,
metadata, numeric/data, code, and annotation. For each role consider:

- content length, language coverage, available weights, font metrics, fallback,
  rendering, licensing, and loading behavior;
- line length, line height, wrapping, truncation policy, and vertical rhythm;
- tabular versus proportional numerals, units, decimals, signs, and alignment;
- real bold/italic faces and whether emphasis remains perceivable in forced
  colors or user styles.

Familiar typefaces are not defects. Distinctive faces are not automatically
appropriate. Change a typeface only when the product, language, brand, or
reading need justifies its lifecycle and performance cost.

## Color, Theme, And Surfaces

Assign semantic roles before choosing swatches: canvas, surface, elevated
surface, text, muted text, border, focus, action, selection, success, warning,
danger, data series, and disabled. Then verify:

- contrast and non-color communication under the adopted target;
- light, dark, high-contrast, forced-color, and dim/bright environments where
  supported;
- overlapping meanings—brand color must not silently become status color;
- translucency against every possible backdrop;
- focus, hover, pressed, selected, loading, and disabled differentiation;
- data-series distinguishability with labels, patterns, shapes, or direct
  annotation where needed.

Dark mode is not color inversion. Re-evaluate elevation, saturation, imagery,
focus, borders, data colors, and perceived contrast.

## Density, Scale, And Rhythm

Density follows task frequency, expertise, device, input precision, content
volume, and consequence. Operational comparison surfaces may need compact
density; onboarding and consumer decisions may need more explanation and touch
space. Compact mode must not shrink text or controls below adopted requirements.

Use a small family of spacing relationships, but do not force every gap onto a
mathematical step when optical grouping needs correction. Repeated exceptions
indicate a missing semantic spacing role or component boundary.

## Imagery And Iconography

- Decide whether an asset informs, demonstrates, proves, identifies, evokes, or
  decorates. Its role determines placement, prominence, alternative text, and
  fallback.
- Prefer real product evidence and approved brand assets over generic imagery.
- Never use real logos as customer proof without verified authorization.
- Preserve focal points and subject integrity across crops; provide a robust
  no-image state.
- Use one coherent icon language. Icons supplement ambiguous labels; they do
  not replace critical text merely to look clean.
- Do not use legal symbols, badges, metrics, or operational strings as visual
  filler.

## Visual State Matrix

Inspect the roles that apply:

| Dimension | Representative states |
|---|---|
| Data | loading, empty, partial, stale, success, error, denied |
| Control | rest, hover, focus, pressed, selected, disabled, busy |
| Content | short, long, missing, localized, bidirectional, unbroken |
| View | narrow, wide, zoomed, portrait, landscape, print if relevant |
| Theme | light, dark, high contrast, forced colors if supported |
| Media | loaded, slow, failed, absent, user-replaced |

Do not render every permutation blindly. Select combinations most likely to
break hierarchy, grouping, legibility, or identity.

## Anti-Default Review

When a familiar AI-generated pattern appears, ask:

1. What relationship or task does it clarify?
2. Would typography, alignment, or spacing alone communicate the same thing?
3. Is it inherited from the product or copied from a visual trend?
4. Does repeating it flatten hierarchy or inflate DOM/design complexity?
5. Does it survive real content, state, theme, and viewport variation?

Keep it when the answers support the product. Remove or reshape it when it is a
default without an owner.
