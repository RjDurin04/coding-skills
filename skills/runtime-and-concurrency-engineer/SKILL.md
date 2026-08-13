---
name: runtime-and-concurrency-engineer
description: Design, implement, diagnose, or review process-local concurrency and runtime resource behavior. Use for threads, async tasks, coroutines, event loops, worker pools, shared mutable state, synchronization, race conditions, deadlocks, cancellation, shutdown, connection or object pools, memory leaks, allocation pressure, garbage collection, handles, sockets, timers, or long-running process stability. Use distributed-systems-engineer instead when correctness spans processes or machines.
---

# Runtime And Concurrency Engineer

Make execution ownership and resource lifetime explicit before choosing a
primitive. Prefer the simplest runtime model that preserves the invariant.

## 1. Establish The Runtime Model

Identify the language/runtime, scheduler, threads or event loops, task/process
pools, blocking boundaries, shared state, callbacks, resource types, and
shutdown entry points. Verify framework guarantees and existing conventions;
do not infer thread safety from names or managed-runtime behavior.

Separate process-local concurrency from distributed coordination. Hand off
cross-process ordering, delivery, consistency, leases, and partitions to
`distributed-systems-engineer`.

## 2. Define Ownership And Invariants

For each mutable value, task, and resource, name its owner, permitted users,
transfer/close rules, and required atomicity or ordering. Model success, error,
timeout, cancellation, retry, re-entry, duplicate completion, and shutdown.

Prefer confinement, immutability, message passing, structured concurrency, or a
single authoritative state transition. Use atomics, mutexes, semaphores,
read/write locks, conditions, channels, or lock-free structures only when their
actual guarantees fit the invariant.

## 3. Prevent Concurrency Failure

Check for check-then-act races, lost updates, unsafe publication, stale
callbacks, lock-order cycles, blocking while locked, starvation, priority
inversion, livelock, re-entrancy, cancellation gaps, and event-loop blocking.
Keep critical sections small and never hold a local lock across unknown or slow
I/O unless the failure model requires and bounds it.

## 4. Control Resource And Memory Lifetime

Bound threads/tasks, pools, queues, buffers, subscriptions, timers, handles,
connections, native allocations, and retained caches. Close resources on every
terminal path and make cleanup idempotent where multiple paths may race.

Use allocation/heap profiles and representative load to distinguish a true
leak from expected caching, delayed garbage collection, fragmentation, or a
temporary high-water mark. Tune garbage collection only after allocation shape,
latency impact, and runtime measurements are known.

## 5. Design Shutdown And Backpressure

Define admission stop, cancellation propagation, drain deadline, partial-work
visibility, resource closure, and restart/replay semantics. When producers can
outpace consumers, bound the buffer and choose block, shed, coalesce, sample, or
reject behavior from user and data consequences.

## 6. Verify

Use the most direct available evidence: race/deadlock tooling, deterministic
scheduler tests, repeated concurrency stress, cancellation and shutdown tests,
leak/handle assertions, heap/allocation profiles, and load/soak tests. State the
runtime, workload, repetition, and state space actually checked.

## Delivery Contribution

Add the runtime model, ownership/invariants, selected primitives, resource
bounds, shutdown/backpressure behavior, evidence, and unresolved scheduler or
runtime assumptions to the unified delivery record in `GEMINI.md`.

## Hard Rules

- Do not use a lock, atomic, channel, pool, or lock-free structure without
  matching its guarantee to a named invariant.
- Do not rely on timing, sleeps, or one passing run as proof of concurrency.
- Do not rely on garbage collection to close scarce external resources.
- Do not turn process-local synchronization into a distributed correctness claim.
