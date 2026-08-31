# Accessible Interface Patterns

Read only the sections matching the current interaction.

## Forms And Validation

- Use programmatic labels, instructions, groups, input purpose, and formats.
- Associate persistent inline errors with controls. An error summary can link to
  invalid fields; a toast is never the sole error channel.
- Preserve entered data where safe. Explain constraints before submission and
  server errors after authoritative validation.
- Move focus only when it helps the user recover; background errors must not
  steal it. Announce a concise change once.
- Do not disable submission merely to suppress validation unless the user can
  understand what is required and reach it.
- Test conditional fields, repeated groups, autosave, timeout, resume, duplicate
  submission, and permission changes.

## Dialogs, Menus, Popovers, And Navigation

- Use the host platform's native or established accessible primitive when it
  fits.
- Provide a name, meaningful initial focus, contained interaction when modal,
  Escape/dismissal behavior where allowed, and focus restoration.
- Keep DOM, visual, and focus order coherent. Hidden surfaces must not remain
  interactive or exposed unintentionally.
- Route changes preserve meaningful title, current location, history, deep
  links, focus, and announcements according to the application contract.
- Hover and pointer discovery require focus/touch equivalents.

## Composite Widgets

For tabs, listboxes, comboboxes, trees, grids, sliders, splitters, and similar
patterns, first ask whether native controls or simpler composition can satisfy
the task. If not, define:

- roles, owned elements, names, values, states, and relationships;
- Tab entry/exit and internal arrow, Home/End, typeahead, selection, escape, and
  activation behavior as applicable;
- focus strategy, disabled items, virtualized items, async updates, and errors;
- touch, pointer, voice, switch, zoom, localization, and bidirectional behavior;
- browser and assistive-technology support evidence.

Partial imitation of a standard pattern can be worse than a simpler control.

## Live Data, Progress, And Notifications

- Keep stable DOM identity and focus while data refreshes.
- Do not announce every tick, row, or percentage. Coalesce meaningful stage,
  alert, failure, and completion changes.
- Provide freshness, completeness, stale/disconnected state, and pause or manual
  refresh when continuous updates create barriers or the adopted target requires
  control.
- Never invent determinate progress. Present honest indeterminate state and
  textual stage information.
- Deduplicate alerts and let users review important history after a transient
  announcement.

## Canvas, Charts, Maps, And Complex Visualizations

Start from the task: compare, locate, inspect, filter, navigate, or act. Provide
an accessible representation and controls that expose the same authorized data,
units, labels, time range, source/freshness, missing values, uncertainty, and
actionable meaning.

Possible representations include a data table, structured list, textual
summary, native controls, or a task-specific nonvisual interface. Hiding the
canvas from assistive technology is correct only after equivalent access is
verified. Test parity across filters, zoom/range, series selection, errors,
empty/partial data, and permission scope.

Tooltips cannot be pointer-only or the sole location of necessary information.
Use labels, patterns, shapes, direct annotation, and non-color cues.

## Drag, Drop, Reorder, And Direct Manipulation

Provide explicit controls or keyboard operations for pick up, move, set value,
cancel, and undo. Expose current position/value, valid targets, constraints, and
result without announcement flooding. Pointer capture loss, invalid drops,
concurrent updates, and reduced motion need safe behavior.

## Media And Documents

- Meaningful images need purpose-equivalent text; decorative images need empty
  alternatives.
- Video and audio need applicable captions, transcripts, descriptions, native
  controls, and user control over autoplay and timing.
- Generated or third-party media does not establish accurate alternative text;
  verify against the actual asset and context.
- Embedded documents and downloads need discoverable format, size, language,
  and an accessible content path appropriate to the adopted target.

## Authentication, Verification, And Timing

Do not depend solely on memory, transcription, puzzle solving, a single sensory
channel, or inaccessible third-party challenges. Provide compatible password
managers, copy/paste, passkeys or alternative verification where supported, and
clear recovery. Timing limits need warning, extension, saved progress, and an
exception path when required; security controls remain authoritative.

## Cognitive And Language Inclusion

Use consistent labels and locations, explicit consequences, manageable choices,
recognition over recall, visible progress, reversible actions, and recovery that
preserves context. Avoid deceptive urgency, confirmshaming, hidden costs, and
ambiguous icon-only controls. Test plain-language alternatives, long/localized
content, reading direction, numeral/date formats, and content that users can
review at their own pace.
