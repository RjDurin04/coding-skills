---
name: quality-engineering-lead
description: Design and govern risk-driven quality strategy across unit, integration, contract, end-to-end, performance, security, accessibility, fuzz, property, mutation, model-based, and failure-injection testing. Use for major features, critical systems, test architecture, flaky or slow suites, weak release confidence, quality gates, coverage effectiveness, or cross-team verification. Use adversarial-test-forge for concrete falsification cases.
---

# Quality Engineering Lead

Build a test system that detects material failures quickly and supports confident
change. Optimize evidence, not test count or coverage percentage.

## 1. Build The Quality Model

Map critical user journeys, contracts, invariants, data/security boundaries,
failure modes, supported environments, and change frequency. Rank risks by impact,
likelihood, detectability, and recovery cost. Define what evidence is required at
local, PR, merge, release, and post-release stages.

Use existing incident, defect, support, and flaky-test data. Do not invent a test
pyramid independent of the system's boundaries and failure history.

## 2. Allocate Test Layers

Choose the cheapest reliable layer that can falsify each risk:

- Types/static analysis for local structural properties.
- Unit/property tests for deterministic logic and invariants.
- Component/integration tests for adapters, persistence, framework, and process boundaries.
- Consumer/provider contracts for independently evolving interfaces.
- End-to-end/synthetic journeys for a few load-bearing workflows.
- Performance, security, accessibility, migration, recovery, and production
  verification where those qualities are material.

Avoid duplicating the same assertion at every layer. Keep important failures
diagnosable and map them to an owner.

## 3. Engineer Reliable Test Infrastructure

Control time, randomness, network, filesystem, locale, concurrency, and external
dependencies. Use deterministic seeds and record failing seeds. Keep fixtures
minimal, representative, isolated, and explicit about tenant/sensitivity.

Separate hermetic tests from deliberate integration/environment tests. Manage
parallelism, ports, database state, cleanup, retries, and resource limits. Treat
quarantine as time-bounded debt with owner and removal criterion; retries must not
hide flakiness.

## 4. Apply Advanced Techniques Selectively

Use:

- Property/fuzz testing for parsers, stateful transforms, protocols, and broad input spaces.
- Mutation testing to measure whether assertions detect plausible defects.
- Model/state-machine testing for ordering, concurrency, workflows, and protocols.
- Differential/golden testing for migrations, compilers, serializers, and replacements.
- Fault/chaos injection for recovery and distributed assumptions in controlled environments.
- Load/soak testing for capacity, leakage, saturation, and long-running behavior.

Pair with `adversarial-test-forge` to generate risk-specific cases and with
`formal-assurance-engineer` for properties requiring stronger evidence.

## 5. Govern Gates And Feedback

Define stable required checks, ownership, budgets, failure triage, and exception
policy. Track escaped defects, false positives, flake rate, duration, queue time,
mutation/evaluation effectiveness, and time-to-diagnosis—not coverage alone.

Feed production incidents and support failures back into regression tests and
`failure-mode-catalog`. Remove tests that add cost without protecting a contract.

## Delivery Contribution

Add the risk model, chosen test layers, quality gates, infrastructure changes,
checks, coverage gaps, and residual confidence limits to the unified delivery
record in `GEMINI.md`.

## Hard Rules

- Tests are evidence, not proof or decoration.
- No critical release gate whose failure is routinely ignored or retried away.
- No production-data leakage into fixtures, logs, snapshots, or test artifacts.
- No metric target without explaining which user or system risk it protects.

