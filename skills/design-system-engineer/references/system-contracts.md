# Design System Contracts

Read this when defining reusable tokens, components, patterns, or artifacts.

## Inventory Before Abstraction

Record:

- products, routes, platforms, framework versions, build/distribution paths;
- token sources, generated artifacts, hard-coded values, themes, and overrides;
- component variants, states, behaviors, consumers, accessibility evidence, and
  known forks;
- product-specific constraints, brand/legal requirements, localization, and
  support matrices;
- ownership, release cadence, contribution flow, and current migration debt.

Group repeated behavior and purpose, not merely repeated names. Two `Modal`
components may have incompatible dismissal or focus semantics; two differently
named controls may share the same contract.

## Token Architecture

A useful default layering is:

1. **Reference primitives** — raw palette, scale, typography, radius, elevation,
   motion, or other source values. Usually private.
2. **Semantic tokens** — roles such as canvas, surface, text, border, focus,
   action, selection, feedback, spacing, or control size. Public to consumers.
3. **Component tokens** — only for a durable component invariant that broader
   semantics cannot express.

Adapt the layers to the project; do not create empty ceremony. Define types,
units, naming, aliases, fallback, output formats, source of truth, generated-file
policy, validation, and deprecation metadata. Prevent product code from reaching
through public semantics into private references.

For each supported theme/brand/density/platform combination, require complete
semantic values or an explicit inherited rule. Check contrast, non-color cues,
focus, selection, disabled state, charts, imagery, elevation, and forced-color
behavior where applicable.

## Component Contract Template

Capture only public behavior:

- purpose and when/not to use;
- anatomy and content requirements;
- state model and authoritative owner;
- public properties, events, slots, or composition API;
- semantic structure, accessible name and relationships;
- keyboard, pointer, touch, focus, dismissal, announcement, and gesture behavior;
- loading, empty, partial, busy, selected, disabled, invalid, denied, failure,
  success, and async/concurrent behavior as relevant;
- responsive, zoom/reflow, long content, localization, bidirectionality, theme,
  density, and reduced-motion behavior;
- performance and DOM/rendering constraints that are actually material;
- supported exceptions and escape hatches;
- tests, documentation, versioning, and owner.

Avoid boolean prop explosions. Prefer composition, explicit variants, and
separate components when states have different invariants. Do not expose
internal DOM/classes/tokens without accepting them as a supported compatibility
surface.

## Patterns And Templates

Patterns combine components around a stable task such as validation, filtering,
bulk selection, destructive confirmation, onboarding, navigation, or data
exploration. Document data and state ownership, sequence, failure/recovery, and
accessibility—not only layout.

Templates and examples are teaching artifacts. Mark illustrative code and
sample content so consumers do not mistake them for supported API or product
truth.

## Cross-Platform Contracts

Share intent, terminology, semantic roles, state, event meaning, and evidence
where they are truly common. Allow web, iOS, Android, desktop, or legacy runtimes
to implement platform-appropriate navigation, focus, gestures, controls, type,
and lifecycle. A shared token name does not justify forcing one implementation
model across platforms.

## Documentation As Contract

For every public primitive/component/pattern, document purpose, boundaries,
anatomy, states, behavior, accessibility, content, theming, density, responsive
variation, examples, anti-patterns, compatibility, version, and migration.
Generate API listings where possible, but retain human-authored decision guidance
that generated docs cannot infer.

## Conformance Evidence

Select relevant checks:

- token schema, type, completeness, alias-cycle, and generated parity;
- component contract and interaction tests;
- keyboard, focus, screen reader, contrast, zoom/reflow, forced colors, reduced
  motion, localization, and media alternatives;
- theme, density, brand, platform, and representative state matrices;
- visual regression using reviewed baselines and content-stress fixtures;
- bundle, rendering, layout, memory, and initialization evidence;
- consumer build/import tests and a real product pilot.

Snapshots are useful only when reviewers understand what change is expected.
Passing catalog stories without representative consumer integration is partial
evidence.
