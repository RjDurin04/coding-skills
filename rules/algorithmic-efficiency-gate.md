---
name: algorithmic-efficiency-gate
trigger: model_decision
description: Apply when code touches growing data, hot paths, queries, transforms, search/sort/group/join logic, or user-visible latency. Prevents accidentally quadratic, memory-unbounded, or query-explosive implementations.
---

Efficiency is a correctness constraint when input size, latency, cost, or resource saturation matters.

## Trigger

Every durable loop, query, transform, search, sort, group, join, dedupe, queue,
cache, pagination path, or collection/file/API processing step over user-sized
or externally sized data must be classified `BOUNDED` or this gate applies.

Use when implementing or reviewing:
- Loops over user records, files, events, messages, rows, graph nodes, or API results.
- Search, sort, group, join, dedupe, pagination, scheduling, matching, routing, or recommendation logic.
- Database queries, ORM relations, indexes, batch jobs, queues, caches, streams, or background workers.
- Code on a latency-sensitive path or any path expected to grow materially over time.

Skip only for tiny fixed-size UI glue or code where input size is provably
bounded and low by a named constant, schema constraint, UI cap, protocol limit,
or local invariant. Skip prototype work only when the user explicitly requested
a disposable spike and the resource risk is disclosed.

## Gate Checks

1. **Input shape:** Name the relevant `n`, `m`, depth, cardinality, page size, file size, payload size, and expected growth.
2. **Asymptotic cost:** State time and space complexity for the main path. Flag nested loops, repeated scans, recursion depth, and materialized collections.
3. **Data structure fit:** Justify arrays/lists/maps/sets/heaps/tries/trees/queues by operation mix, not habit.
4. **I/O and query shape:** Check for N+1 queries, missing indexes, full scans, unbounded pagination, chatty APIs, and per-item network calls.
5. **Memory and backpressure:** Bound buffers, streams, batches, caches, queues, recursion, and fan-out. Define eviction or invalidation when caching.
6. **Approach comparison:** Reject weaker algorithm/query shapes when a simple better fit exists. Do not keep accidental O(n^2), query-in-loop, or memory-unbounded work because it was quicker to code.
7. **Measurement:** For non-obvious optimizations, prefer profiler/benchmark evidence. Do not add clever code for speculative speed.
8. **Regression guard:** Add tests or benchmarks when performance is a requirement, a bug fix, or a likely future regression point.

## Delivery Contribution

For material paths, add input shape/boundedness, time-space or query choices,
measurement evidence, rejected weaker options, and remaining risk to the unified
delivery record in `GEMINI.md`.

## Hard Rules

- A query in a loop is guilty until proven bounded.
- A "small input" claim needs evidence: constant, schema constraint, UI cap,
  protocol limit, local invariant, fixture limit, or explicit requirement.
- Unbounded input requires pagination, streaming, batching, limits, or backpressure.
- Do not trade readability for speed unless scale, profiling, or requirements justify it.
- A cache without an invalidation/eviction story is not an optimization; it is stored uncertainty.
