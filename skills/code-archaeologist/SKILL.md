---
name: code-archaeologist
description: Use before changing or diagnosing unfamiliar existing code, load-bearing behavior, or non-trivial generated code. Reconstruct callers, contracts, state, ownership, and failure modes from current evidence while treating unexplained code as an unverified constraint, not proof of intentional design.
---

# Code Archaeologist

Build enough understanding for the task's consequence before editing.

## 1. Preserve Current Work

Inspect relevant uncommitted changes and generated-file boundaries first.
Assume unrelated modifications belong to the user. Do not overwrite, revert, or
reinterpret them without evidence and authority.

## 2. Map The Execution Path

Trace:

- entry points, callers, callees, jobs, events, and user flows;
- input parsing, transformations, persistence, output, and side effects;
- public and implicit contracts, including errors and timing;
- authorization, invariants, transactions, retries, and failure recovery;
- module, feature, service, or operational ownership.

Search for existing helpers and conventions before proposing new structure.

## 3. Weigh The Evidence

Inspect nearby tests, fixtures, schemas, examples, runbooks, configuration, ADRs,
and comments. Use history or blame when available and decision-relevant, but
remember that documentation and old commits can be stale.

Classify code as load-bearing, boundary, generated, presentation or glue,
apparently unused, or unclear. If a suspicious line cannot yet be explained,
treat it as an `UNVERIFIED CONSTRAINT`: preserve it until callers, tests,
history, runtime evidence, or an owner decision establishes whether it is
required. Do not presume it was intentional or correct.

## 4. Predict The Change

Before editing, be able to state:

- what relevant callers observe now and after the change;
- what data or permissions could be lost, leaked, corrupted, or duplicated;
- which failure modes or dependencies change;
- which checks could detect a bad edit;
- what remains unknown.

For low-risk local work, a bounded disclosed assumption may be enough. For
load-bearing or irreversible work, a material unexplained contract is a blocker.

## Hard Rules

- Apparent age, complexity, or lack of references is not proof that code is
  obsolete.
- A comment or ADR is evidence, not guaranteed current truth.
- Do not accept generated code whose material contracts and risks remain
  unexplained.
