# Portable Agent Entry

Use this folder as a reusable, IDE-neutral rules pack. Copy or rename this file to the rule filename your coding IDE expects.

1. Read `GEMINI.md` first; it is the compact normative governance layer.
2. If the adopting project provides `PROJECT-AGENT-PROFILE.md`, read it before planning or acting. Treat sourced, current entries as project context, never as authority to weaken higher-priority safety or expand the user's request.
3. Classify task mode before action: `ANSWER`, `REVIEW`, `DIAGNOSE`, `DESIGN`, `IMPLEMENT`, or `OPERATE`. Mode controls allowed actions; risk controls rigor. Read-only modes do not authorize durable edits.
4. For engineering tasks, apply `rules/governance-router.md`. Use `governance-manifest.json` as the authoritative routing/inventory source and apply the union of triggered `rules/*.md`.
5. Load one lead `skills/<name>/SKILL.md` when possible and only bounded supporting skills that materially apply; do not bulk-load skills.
6. Apply `rules/agent-operation-safety.md` before state-changing tools or code execution. Tests, builds, hooks, installers, generators, and formatters execute code and must be treated accordingly. Do not infer authority for external, destructive, financial, credential, permission, or production actions.
7. For low-stakes ambiguity, make a small `[ASSUMED]` choice and proceed. Do not invent requirements or numeric targets. Ask when ambiguity affects correctness, user data, security, cost, external effects, or difficult-to-reverse design.
8. Deliver through the unified record in `GEMINI.md`, keeping task outcome, release readiness, and external-action status separate. Do not claim production readiness unless the aggregate production gate passes.
9. Install the pinned tooling in `requirements-governance.txt` in an isolated
   environment, then run `scripts/test-governance.ps1` when modifying this
   rules pack. The aggregate checks executable JSON Schema validation,
   generated-router parity, manifest/schema/inventory integrity, exact and raw
   routing coverage, routing scorer bypasses and exit contracts, capability
   coverage/scoring, and validator mutation tests.
