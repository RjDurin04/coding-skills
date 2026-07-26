---
name: performance-engineer
description: Use when code touches hot paths, growing datasets, algorithm/data-structure choices, database query shape, memory pressure, batching, caching, or user-visible latency. Designs and reviews efficient implementations without speculative cleverness.
---

# Performance Engineer

Use when speed, throughput, memory, cost, or user-visible latency matters: hot paths, growing data, nested loops, queries in loops, unbounded collections/recursion/fan-out, batch jobs, pagination, indexes, caches, or asks like "slow", "fast", "optimize", "efficient", "scalable". Skip tiny fixed-size glue unless hot.

## Execution Protocol

### 1. Workload First

```
n = primary items
m = related items
d = depth / fan-out
k = page or batch size
growth = current -> expected 12-month size
target = p95/p99, throughput, memory, CPU, API cost
```

If no target exists: choose a low-stakes `[ASSUMED]` default only when it does
not affect architecture, cost, correctness, security, data safety, or public
behavior; otherwise ask.

### 2. Complexity Pass

For each material path, state:
- **Time:** common/worst/expected when they differ.
- **Space:** temp arrays/maps, buffers, caches, recursion, materialized results.
- **I/O:** DB queries, network calls, file ops, locks, queue ops.

Red flags: nested independently growing inputs; repeated sort/filter/find in a loop; query/network call in a loop; full scan, missing index, deep offset pagination; unbounded recursion, fan-out, queue, cache, or payload.

### 3. Data Structure Fit

| Need | Usually prefer |
|---|---|
| Membership / dedupe | Set |
| Keyed lookup / grouping | Map / dictionary |
| Ordered top-k | Heap / priority queue |
| Prefix lookup | Trie or indexed search |
| Range query | Sorted structure / database index |
| FIFO/LIFO work | Queue / stack |
| Sparse graph traversal | Adjacency map plus visited set |

Pick the simplest structure matching dominant operations. If using a list for repeated lookup, justify bounded `n` or readability.
If a better-fit structure or query shape is simple and local, reject the weaker
choice explicitly instead of accepting accidental slow paths.

### 4. Shape I/O And Memory
- Replace per-item queries with joins, preloads, batched lookups, or explicit pagination.
- Verify indexes match filters, joins, sorts, and uniqueness.
- Prefer keyset pagination for large/deep result sets.
- Batch network calls with concurrency limits.
- Stream large files/results; materialize only bounded data.
- Define backpressure when producers can outrun consumers.

### 5. Cache Carefully

Cache only for measured/structurally obvious repeated work. Define key/scope, TTL or eviction/invalidation, staleness tolerance, memory bound, and stampede/concurrency behavior. No invalidation story means no cache.

### 6. Measure Before Cleverness

Baseline with profiler, benchmark, query plan, or production metric; change one bottleneck; re-measure with representative data. Keep clearer code unless the faster version materially meets a requirement or removes risk. Micro-optimize only after algorithm, I/O shape, and memory bounds are sane.

### 7. Guard Regression

Use the lightest useful guard: unit/property tests for boundary/invariants, ORM query-count tests, stable algorithm benchmarks, load/soak tests, or alerts for p95/p99 latency, saturation, queue depth, and cache hit rate.

## Delivery Contribution

When performance matters, add the relevant workload, time/space/I/O
complexity, data-structure or query-plan decision, rejected weaker option,
measurement evidence, regression guard, and residual risk to the unified
delivery record in `GEMINI.md`. Do not introduce a second status vocabulary or
use a local performance result to imply aggregate release readiness.

## Hard Rules

- First optimize the shape of work.
- A faster wrong answer is still wrong.
- A clever algorithm with unverified assumptions is future maintenance debt.
- If input is unbounded, the implementation must bound memory, latency, or concurrency.
- If performance is a requirement, at least one scoped check must measure it or
  a monitoring guard must detect violation.
