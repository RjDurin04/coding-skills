---
name: security-and-privacy-gate
trigger: model_decision
description: Apply when code touches trust boundaries, auth, sensitive data, secrets, external input, data-bearing forms/UI, or security-relevant configuration.
---

Security and privacy are design constraints at every trust boundary. For general
UI accessibility with no form, data, or trust boundary, use the
`interface-designer` skill; the checks below cover accessibility where this gate
already applies.

## Trigger
Use for authn/authz, user input, DB queries, secrets, telemetry that contains
sensitive or linkable data or crosses a trust boundary, customer-facing forms,
security-relevant configuration, or UI that handles data or untrusted rendered
content. Dependency/build changes also use
`rules/supply-chain-and-build-integrity.md`; runtime configuration/flags also
use `rules/configuration-and-feature-flags.md`.

## Gate Checks

### 1. Security & Auth
- **Boundaries:** Identify untrusted inputs; parse to typed data at the edge.
  Prevent applicable SQL/NoSQL/command/template/header/log injection and encode
  untrusted output for its destination.
- **Authz & Tenancy:** Enforce server-side at the data boundary. Every touched
  protected, tenant-scoped, or access-controlled table/object has applicable
  policy/rule coverage.
- **Secrets:** No secrets in source, client bundles, logs, errors, tests, or analytics.
- **Browser & Session:** As applicable, verify CSRF and CORS boundaries, secure
  cookie/session/token handling, safe redirects, and content-rendering controls.
- **Files & URLs:** Bound size/type/archive expansion, normalize paths, prevent
  traversal and unsafe serving, and constrain outbound URLs against SSRF,
  redirect, DNS, and internal-network abuse.
- **Abuse & Resources:** Bound replay, attempts, rate, concurrency, fan-out,
  payload, and expensive operations at the authoritative boundary.

### 2. Privacy & Data Governance
- **Classification & minimization:** Classify sensitive data and collect only required fields.
- **Lifecycle:** Define applicable purpose, access, retention, deletion, export, residency, and consent/legal-basis requirements. Do not invent legal conclusions; escalate them for qualified review.
- **Protection:** Use project-appropriate encryption in transit/at rest and managed key/secret rotation. Logs, traces, errors, support tools, and backups must not expose unnecessary sensitive data.
- **AI Use:** Do not send sensitive data to external AI services unless the data class, user agreement, vendor terms, retention, and access policy explicitly permit it.
- **Consequence:** Routine bounded use through an established, unchanged,
  server-enforced boundary may be Standard. New/changed authorization or
  sensitive-data boundaries, regulated/bulk/cross-tenant handling, and credible
  high-impact exposure remain Critical.

### 3. Supply Chain Integrity
- Apply `rules/supply-chain-and-build-integrity.md`; consume its dependency,
  build, provenance, and vulnerability findings here when they affect a trust
  boundary.
- Minimize total lifecycle/security risk, not dependency count. Do not implement
  bespoke cryptography, authentication/authorization, security protocols, or
  standards-heavy parsers merely to avoid a package. Prefer a maintained,
  appropriately scoped dependency when custom code is riskier.

### 4. Accessibility
- **Keyboard & Semantics:** Ensure semantic HTML. Every control is reachable by keyboard.
- **Errors & Contrast:** Errors must identify the field. Follow the project's
  applicable, versioned accessibility target. For new web work without an
  adopted target, use WCAG 2.2 AA as a provisional engineering baseline, record
  that it is not an adopted contractual or compliance claim, and surface target
  adoption to the responsible owner.

## Block Release If:
Authorization is unknown; a secret is exposed; sensitive telemetry cannot be
redacted; a material dependency/build-integrity risk is unresolved; or critical
UI is inaccessible.

## Delivery Contribution

Add only material controls verified, checks run, blockers, warnings, and privacy
unknowns to the unified delivery record in `GEMINI.md`.
