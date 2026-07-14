---
name: distributed-systems-engineer
description: Design and review workflows spanning processes, services, queues, regions, replicas, schedulers, or unreliable networks. Use for delivery semantics, ordering, consistency, coordination, clocks, retries, idempotency, sagas, outboxes, leader election, partitions, split brain, distributed concurrency, or cross-service failure handling. Do not use for a local synchronous call graph.
---

# Distributed Systems Engineer

Make time, partial failure, and independent state explicit. First determine
whether distribution is necessary; a local transaction is often safer.

## 1. Draw The System And State

Identify processes/services, state owners, communication edges, trust boundaries,
failure domains, and operators. For each edge define protocol, timeout, retry,
backpressure, authentication, and what each side can know after failure.

Name authoritative state, replicas/caches, permitted staleness, and the operation
whose user-visible outcome must remain correct.

## 2. Choose Consistency And Delivery Semantics

Define:

- Consistency requirement per read/write, not for the system as a slogan.
- Delivery guarantee and duplicate, loss, replay, and poison-message behavior.
- Ordering scope: none, per key, per partition, causal, or total—and why.
- Idempotency identity, dedupe retention, and side-effect boundary.
- Clock assumptions, deadline source, timezone, skew, and monotonic versus wall
  time.
- Behavior during partitions, dependency outage, and ambiguous timeout.

Do not claim exactly-once end-to-end effects without proving every stateful
boundary. Prefer at-least-once delivery plus idempotent effects when it fits.

## 3. Design State Transitions And Coordination

Model durable states, transitions, guards, terminal states, and compensations.
Choose local transaction, outbox/inbox, saga, lease, fencing token, quorum,
consensus, or coordinator only when its guarantees match the invariant.

Prevent stale leaders and expired workers from committing effects. Define
ownership transfer, lease renewal, lock/fencing scope, recovery after crash, and
how incomplete work is discovered.

## 4. Control Failure Amplification

Bound retries with backoff/jitter and a total deadline. Cap concurrency, queue
depth, fan-out, payload, and replay. Prevent retry storms, thundering herds,
duplicate notifications/payments, cache stampedes, and poison loops. Define
degrade, shed, isolate, circuit-break, or fail-fast behavior from user impact.

Instrument correlation/causation IDs, state transitions, lag, age, retries,
dedupe, saturation, dead letters, invariant violations, and recovery progress.

## 5. Verify The Failure Model

Test duplicate, delay, loss, reordering, concurrent ownership, clock skew,
timeout after commit, crash between steps, dependency outage, partition, stale
replica, poison data, and recovery/replay. Use deterministic simulation or model
checking for critical protocols when practical; pair with
`formal-assurance-engineer` for high-assurance state machines.

## Delivery Contribution

Add the state/edge map, chosen consistency and delivery semantics, coordination
mechanism, bounded failure behavior, tests, and remaining assumptions to the
unified delivery record in `GEMINI.md`.

## Hard Rules

- A timeout does not prove whether the remote effect occurred.
- No exactly-once, global order, strong consistency, or failover claim without a
  precise scope and evidence.
- No unbounded retry, queue, fan-out, lease, or replay behavior.
- Prefer removing a distributed boundary when it does not buy a required outcome.

