---
name: drift-guardian
description: Use when a change creates actual boundary pressure, such as a new cross-module dependency, bypassed public interface, duplicated policy, circular reference, ownership ambiguity, repeated exception, or broad shared abstraction. Distinguish harmful erosion from intentional architecture evolution and add proportional guards.
---

# Drift Guardian

Do not engage merely because a repository has multiple modules or a file is
large. Look for a concrete pressure on ownership, dependency direction, or a
protected contract.

## 1. Establish The Current Boundary

Identify the owner, public surface, allowed dependencies, relevant data and
transaction boundary, and evidence that the boundary is current. Use code,
tests, build rules, module manifests, and maintained decisions. If no coherent
architecture exists, describe the observed convention and uncertainty instead
of inventing a layered or domain model.

## 2. Name The Pressure

Examples include:

- importing an internal implementation across ownership boundaries;
- duplicating a business or authorization invariant;
- creating a circular or bidirectional dependency;
- sharing mutable data without a contract;
- adding a generic abstraction before multiple consumers need it;
- accumulating temporary adapters or exceptions without exit conditions.

Explain the concrete consequence: change amplification, inconsistent policy,
unsafe data access, deployment coupling, broken isolation, or unclear ownership.

## 3. Compare Evolution Paths

Compare the smallest local change, use of the current public boundary, and a
deliberate boundary revision when each is viable. A boundary may need to evolve;
do not preserve it solely because it already exists. If revising it, update
owners, contracts, callers, tests, and maintained architecture records together.

## 4. Guard Proportionally

Add or propose an import rule, architecture test, contract test, schema
constraint, lint rule, or maintained decision only when recurrence is plausible
and the guard costs less than repeated review. A one-time low-risk deviation may
need only a documented decision and cleanup condition.

## Hard Rules

- Local verified architecture beats generic layering advice.
- Do not call normal collaboration between modules drift without a violated or
  newly contested boundary.
- Do not route around a real boundary conflict with hidden coupling.
