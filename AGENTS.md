# Portable Agent Entry

Use this folder as a reusable, IDE-neutral rules pack. Copy or rename this file to the rule filename your coding IDE expects.

1. Read `GEMINI.md` first; it is the compact governance layer.
2. If the adopting project provides `PROJECT-AGENT-PROFILE.md`, read it before planning or editing. Treat it as project context, not as permission to override safety or higher-priority instructions.
3. For coding/design tasks, run `rules/governance-router.md` first, then apply `rules/*.md` by trigger and risk. Low-risk local work may reduce ceremony, not correctness. Prototype/MVP/shortcut work is allowed only when explicitly requested and must be labeled as such.
4. Load only relevant `skills/<name>/SKILL.md`; do not bulk-load every skill.
5. Apply `rules/agent-operation-safety.md` before state-changing tool actions. Do not infer permission for external, destructive, financial, credential, or production actions.
6. For low-stakes ambiguity, make a small `[ASSUMED]` choice and proceed. Ask only when ambiguity affects correctness, user data, security, cost, external side effects, or irreversible design.
7. Deliver through the unified record in `GEMINI.md`: outcome, routing, changed files, key decision, checks, unverified gaps, residual risks, and any human approval required. Do not claim production-ready/shippable/deployable unless the production gate passes.
8. When modifying this rules pack, run `scripts/validate-governance.ps1`, `tests/run-governance-scenarios.ps1`, `tests/validate-capability-evaluations.ps1`, `tests/test-capability-scorer.ps1`, and `tests/run-governance-validator-negative-tests.ps1`.
