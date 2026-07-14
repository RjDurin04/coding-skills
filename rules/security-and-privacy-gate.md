---
name: security-and-privacy-gate
trigger: model_decision
description: Apply when code touches auth, user data, secrets, external input, dependencies, data-bearing forms/UI, or production config. This unifies security, privacy, supply chain, and related accessibility checks.
---

Security and privacy are design constraints at every trust boundary. For general
UI accessibility with no form, data, or trust boundary, use the
`interface-designer` skill; the checks below cover accessibility where this gate
already applies.

## Trigger
Use for authn/authz, user input, DB queries, secrets, telemetry, new
dependencies/packages, customer-facing forms, or UI that handles data or
untrusted rendered content.

## Gate Checks

### 1. Security & Auth
- **Boundaries:** Identify untrusted inputs; parse to typed data at the edge. Prevent SQL/NoSQL/Command injection.
- **Authz & Tenancy:** Enforce server-side at the data boundary. Every touched table/object has policy/rule coverage.
- **Secrets:** No secrets in source, client bundles, logs, errors, tests, or analytics.

### 2. Privacy & Data Governance
- **Classification & minimization:** Classify sensitive data and collect only required fields.
- **Lifecycle:** Define applicable purpose, access, retention, deletion, export, residency, and consent/legal-basis requirements. Do not invent legal conclusions; escalate them for qualified review.
- **Protection:** Use project-appropriate encryption in transit/at rest and managed key/secret rotation. Logs, traces, errors, support tools, and backups must not expose unnecessary sensitive data.
- **AI Use:** Do not send sensitive data to external AI services unless the data class, user agreement, vendor terms, retention, and access policy explicitly permit it.

### 3. Supply Chain Integrity
- **Need & Identity:** Prefer stdlib or local code before adding dependencies. Verify package existence/ownership (avoid typosquats).
- **Versioning & Security:** Follow the project's lock/pinning policy. Check advisories, maintenance, transitive risk, install scripts/native code, license compatibility, and provenance.
- **Release Evidence:** For applicable production releases, generate or verify an SBOM and artifact/build provenance; use signing where the delivery system supports trustworthy verification.

### 4. Accessibility
- **Keyboard & Semantics:** Ensure semantic HTML. Every control is reachable by keyboard.
- **Errors & Contrast:** Errors must identify the field. Ensure WCAG 2.1 AA contrast.

## Block Release If:
Authorization is unknown; a secret is exposed; sensitive telemetry cannot be redacted; an unverified dependency is added; or critical UI is inaccessible.

## Delivery Contribution

Add only material controls verified, checks run, blockers, warnings, and privacy
unknowns to the unified delivery record in `GEMINI.md`.
