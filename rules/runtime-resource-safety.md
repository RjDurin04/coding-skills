---
name: runtime-resource-safety
trigger: model_decision
description: Apply to local concurrency, asynchronous execution, event loops, threads, processes, synchronization, cancellation, pools, and memory or resource lifecycle behavior.
---

# Runtime Resource Safety

Correct local concurrency requires explicit ownership, lifecycle, and shutdown
semantics. Do not treat a single process as failure-free or race-free.

## Trigger

Threads, tasks, futures, coroutines, event loops, worker/process pools, shared
mutable state, synchronization primitives, cancellation, background work,
connection or object pools, native resources, allocation pressure, garbage
collection, memory/resource leaks, or long-running runtime behavior.

## 1. Map Execution And Ownership

- Identify execution contexts, shared state, mutable owners, queues, blocking
  operations, callbacks, and re-entrancy.
- Define who creates, may use, transfers, closes, cancels, and observes each
  resource or task.
- State which operations must be atomic, ordered, isolated, or safe to repeat.
- Verify the language/runtime memory and scheduling model instead of assuming
  that syntax such as `async`, an event loop, or a managed runtime makes code
  thread-safe.

## 2. Choose Coordination Deliberately

- Prefer confinement, immutability, message passing, structured concurrency, or
  an atomic database/state transition before broad shared locking.
- When locking is required, define protected state, lock scope, ordering,
  re-entrancy, timeout/cancellation behavior, and work forbidden while held.
- Prevent lost updates, check-then-act races, double completion, stale callbacks,
  starvation, priority inversion, livelock, and deadlock as applicable.
- Use distributed leases or locks only under `distributed-systems-engineer`;
  process-local locks cannot protect cross-process state.

## 3. Bound Work And Resource Lifetime

- Bound threads/tasks, queues, buffers, pools, in-flight work, allocation rate,
  retries, and fan-out. Define overload and backpressure behavior.
- Close files, sockets, streams, transactions, subscriptions, timers, handles,
  and native resources on success, error, timeout, and cancellation paths.
- Treat garbage collection as memory reclamation, not lifecycle management for
  scarce external resources. Avoid finalizers as the primary correctness path.
- For long-running processes, check retained object graphs, unbounded caches or
  listeners, fragmentation, pool exhaustion, and repeated allocation/collection
  pauses against representative workload.

## 4. Shutdown And Recovery

Define admission stop, cancellation propagation, draining, deadline, partial
completion, resource release, and restart/replay behavior. Shutdown must not
silently drop accepted work or hang indefinitely. Preserve the last safe state
and expose incomplete work when recovery is required.

## 5. Verify The Runtime Model

Use applicable deterministic scheduling, race/deadlock detectors, concurrency
stress tests, cancellation tests, leak/handle checks, heap/allocation profiles,
and load/soak tests. A timing-dependent test that passed once is weak evidence;
control scheduling where possible and retain a bounded repeated or diagnostic
check where it protects a material invariant.

## Delivery Contribution

Record the execution/ownership model, protected invariants, coordination and
lifecycle choices, bounds, shutdown behavior, checks, and remaining runtime
assumptions in the unified delivery record in `GEMINI.md`.

## Hard Rules

- No shared mutable state without a named owner and synchronization contract.
- No unbounded task, thread, queue, pool, buffer, subscription, or resource life.
- No blocking call on a latency-sensitive event loop without an explicit safe
  offload or bounded justification.
- Garbage collection does not replace deterministic release of scarce resources.
- No thread-safety, leak-free, or deadlock-free claim without scoped evidence.
