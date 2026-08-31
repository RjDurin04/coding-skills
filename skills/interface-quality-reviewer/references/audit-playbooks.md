# Interface Audit Playbooks

Apply the playbook matching the surface type under review.

## 1. Creative Portfolios And Marketing Sites

- **Media and Performance**: Inspect asset loading strategies (lazy loading, responsive `srcset`, modern formats), placeholder behavior (LQIP, blur-up), and bandwidth constraints.
- **Scroll and Motion**: Verify that scroll-linked effects, parallax, and entrance transitions remain performant (compositor-only properties: `transform`, `opacity`), do not stutter, and degrade gracefully when `prefers-reduced-motion: reduce` is enabled.
- **Navigation and Wayfinding**: Test menu toggles, anchor jumps, fixed headers, and back-button behavior across mobile and desktop.
- **Typography and Hierarchy**: Check reading order, line lengths (45–75 characters), contrast across varying background images, and font fallback behavior.
- **Evidence Calibration**: Do not judge responsiveness solely from resized desktop windows; check real touch targets and mobile viewport scaling.

## 2. SaaS Operations Workflows And Dashboards

- **Task Density vs. Clarity**: Ensure data-dense tables, lists, and summary cards remain scannable with clear visual hierarchy and distinct primary actions.
- **State Coverage**: Check loading skeletons, empty states with clear calls to action, stale data indicators, error banners with retry triggers, and partial data rendering.
- **Permissions and Roles**: Verify that read-only vs. editable fields correctly reflect authorization states, with disabled controls explaining why an action is unavailable.
- **Tables, Filters, and Search**: Test column sorting, pagination controls, filter clearing, zero-result states, and keyboard navigation within complex grids.
- **Data Integrity**: Verify unit labels, number formatting, timezone handling, and truncation with tooltips on overflow.

## 3. Form-Heavy And Transactional Surfaces

- **Input Affordances**: Check clear labeling, input types (`email`, `tel`, `number`), autocomplete attributes, and field constraints.
- **Validation and Error Recovery**: Verify inline validation timing (avoid premature error on blur before typing), field-level error messages linked via `aria-describedby`, and preservation of entered values upon failure.
- **Submission and Feedback**: Test loading spinners, disabled double-submission protection, success confirmations, and actionable error summaries.
- **Sensitive Data**: Verify that masked inputs (passwords, payment cards) do not leak sensitive values into DOM or client logs.

## 4. Developer Tools And Complex Workspaces

- **Keyboard-First Operation**: Verify full keyboard shortcuts, command palette interactions, tab navigation, and focus traps within dialogs and drawers.
- **Pane Resizing and Layout Persistence**: Test splitters, collapsibles, responsive drawer transitions, and state recovery on reload.
- **Asynchronous Diagnostics**: Inspect log streams, live output terminals, syntax highlighters, and error consoles under rapid update bursts.
- **Virtualization and DOM Health**: Check that long lists and code blocks virtualize smoothly without losing focus or breaking screen-reader access.
