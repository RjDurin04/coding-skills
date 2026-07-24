---
name: laravel-react-inertia
description: Optional Laravel, React, and Inertia project overlay. Apply only when PROJECT-AGENT-PROFILE.md explicitly adopts overlay id `laravel-react-inertia`; repository-pinned versions, current architecture, lockfiles, verified commands, and project-specific profile values override these fallback preferences.
---

# Laravel React Inertia Overlay

## Activation Gate

Apply this overlay only after reading an adopting project's
`PROJECT-AGENT-PROFILE.md` and finding an explicit adoption of:

```text
laravel-react-inertia
```

If the id is absent, do not use this overlay implicitly because a repository
happens to contain PHP, Laravel, React, or Inertia.

## Precedence

Use this order inside the adopting project:

1. repository lockfiles, manifests, configuration, tests, and working code;
2. verified project-profile versions, architecture, commands, and exceptions;
3. this overlay's fallback preferences.

Do not add, remove, or upgrade a dependency merely to match this overlay. Verify
framework and package compatibility against the repository's actual versions.

## Fallback Application Shape

When the project leaves a choice open and requirements support it:

- Prefer a Laravel application with React, TypeScript, Inertia, and Vite for a
  server-driven monolith UI.
- Prefer strict TypeScript and the repository's existing PHP static-analysis,
  formatting, test, and frontend-check tools.
- Use Laravel validation, authorization policies or gates, transactions,
  queues, events, storage, caching, and rate limiting through established local
  seams.
- Keep authorization and validation server-side even when the client duplicates
  checks for usability.
- Pass page data through typed Inertia props; keep transient UI state local and
  introduce global client state only for demonstrated cross-page needs.
- Reuse the project's design tokens, components, form, modal, table, routing,
  notification, and accessibility patterns before adding alternatives.
- Prefer generated or verified route helpers over handwritten route strings
  when the repository already supports them.

## Architecture And Data

Start from the repository's current ownership model. A modular monolith is a
candidate when new boundaries are needed; DDD, `app/Features`, Actions, Services,
DTO packages, repositories, or ports/adapters are not automatic requirements.

Prefer database constraints plus application validation for durable invariants.
Use transactions for atomic multi-write behavior and explicit idempotency for
retryable side effects. Choose PostgreSQL, Redis, object storage, search,
websockets, payment, AI, or feature-flag providers only from actual workload,
operational, compliance, and deployment constraints.

## API And Operations

Use Inertia routes for the first-party monolith UI. Add a versioned API only for
real external, mobile, integration, or independently deployed consumers, with
explicit authentication, authorization, serialization, compatibility, and
rate-limit contracts.

Use verified project commands and deployment configuration. Do not assume
`composer dev`, a package manager, CI provider, queue backend, cloud platform,
cache strategy, or production service merely because it appeared in another
Laravel project.

## Hard Rules

- Repository pins override overlay preferences.
- Existing verified architecture overrides generic Laravel conventions unless a
  deliberate migration is approved.
- The overlay narrows project choices; it does not grant authority or lower
  security, data, testing, or release requirements.
