---
name: supply-chain-and-build-integrity
trigger: model_decision
description: Apply to dependencies, repository build execution, CI, generated artifacts, provenance, distribution, and vulnerability response.
---

# Supply Chain And Build Integrity

The build path is a trust boundary. A passing build proves neither source
integrity nor artifact safety.

## Trigger

Dependency add/update/remove; package install; lockfiles; version or resolver
policy; plugins/actions/images; build or dependency caches;
unfamiliar, privileged, dependency-resolving, or artifact-producing
tests/builds/hooks/generators; CI runners; compilers/toolchains; artifact
packaging, signing, publishing, or provenance; dependency/source compromise; and
vulnerability intake/remediation. Routine known, locked, local checks use
`rules/agent-operation-safety.md` without loading this full gate unless another
trigger matches.

## 1. Dependency And Input Trust

- Establish need by total lifecycle/security risk, not a zero-dependency goal.
  Do not hand-roll crypto, auth, security protocols, or standards-heavy parsers
  merely to avoid a maintained library.
- Verify identity, authoritative source/registry, ownership/maintenance,
  version/lock policy, integrity metadata, license, advisories, transitive
  dependencies, install scripts, native code, runtime privileges, and
  replacement path proportionally.
- Pin or lock inputs according to the project delivery model. Review lockfile and
  resolved-source changes; package names and version strings alone are not
  identity evidence.
- Treat Semantic Versioning ranges as compatibility claims, not proof. Inspect
  the actual public surface, changelog/advisory, resolver result, peer/runtime
  constraints, and lock diff; bound duplicate versions and resolver drift.

## 2. Safe Build Execution

Repository tests, builds, hooks, installers, generators, formatters, actions,
containers, and plugins execute code. Apply
`rules/agent-operation-safety.md`: inspect unfamiliar entrypoints/lifecycle
scripts, use least privilege and isolated disposable state, remove ambient
production credentials, constrain network/filesystem/fan-out/cost, and stop on
unexpected access or mutation.

CI/build identities should have only required permissions, immutable or reviewed
workflow definitions, isolated untrusted contributions, protected secrets, and
scoped artifact/repository write access. Do not run untrusted change code with
release credentials.

Build caches need a declared trust and correctness contract: key all material
source, dependency, toolchain, platform, feature, and configuration inputs;
separate untrusted forks/tenants from privileged jobs; prevent path traversal
and cache poisoning; avoid caching secrets or signed outputs; verify restored
artifacts before promotion; and provide bounded invalidation or clean rebuild.
A faster stale or attacker-controlled build is a failed build.

## 3. Artifact Identity And Provenance

- Bind an artifact to reviewed source, dependency/lock inputs, toolchain, build
  workflow/identity, parameters, and checks.
- Make builds reproducible enough to investigate/rebuild the release model; name
  unavoidable nondeterminism.
- Produce/verify an SBOM, provenance, checksums, and signatures when the threat
  model or distribution path can consume them meaningfully. Ceremony without a
  verifier is not assurance.
- Verify the exact artifact promoted between environments; rebuilding creates a
  different artifact requiring new evidence.

## 4. Vulnerability And Compromise Response

Define intake, triage owner, severity/exploitability assessment, affected-version
inventory, embargo/access handling, containment, patch/update/backport choice,
regression/security verification, rebuild/revocation, and release criteria.
Coordinate disclosure and downstream/customer notification with authorized
security/legal owners; do not invent obligations or publish unilaterally.

After a confirmed compromise, distrust affected credentials, runners, caches,
dependencies, provenance, and artifacts until the blast radius is established.
Rebuild from a verified clean path and feed recurrence prevention into controls
and tests.

## Delivery Contribution

Record material input/artifact identity, execution constraints, provenance,
findings, affected versions, verification, unresolved exposure, and authorized
response owner. External publication/revocation status remains separate.

## Release Blockers

Block `READY` for unresolved critical exploitable findings; unknown artifact
identity; untrusted build execution with release credentials; integrity/provenance
required by the delivery model but missing; or compromise without a verified
clean rebuild/recovery path.
