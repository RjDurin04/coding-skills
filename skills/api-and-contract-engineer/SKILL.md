---
name: api-and-contract-engineer
description: Design and review durable HTTP, RPC/gRPC, GraphQL, streaming, event, webhook, schema, SDK-facing, and inter-module contracts. Use for new or changed public contracts, WebSockets, Server-Sent Events, long polling, versioning or compatibility, pagination, idempotency, errors, rate limits, consumer migration, or contract testing. Do not use for a purely internal function with no stable consumers.
---

# API And Contract Engineer

Treat every durable interface as a consumer-owned contract, not merely a handler
signature.

## 1. Inventory Consumers And Semantics

Identify producers, consumers, trust boundaries, protocol, ownership, expected
lifetime, call volume, latency, and compatibility expectations. Inspect existing
schemas, generated clients, examples, tests, telemetry, and deprecation policy.

Define the resource/action/event semantics before choosing fields. State
preconditions, postconditions, side effects, consistency, authorization, and
whether retries or reordering are possible.

## 2. Design The Contract

Specify applicable elements:

- Request/response/event schema, types, null/missing semantics, units, timezones,
  enums, defaults, and unknown-field behavior.
- Identity, authorization scope, tenant/object checks, and data minimization.
- Idempotency, deduplication, conditional writes, concurrency/version tokens, and
  replay behavior.
- Pagination stability, ordering, filtering, search, field selection, and limits.
- Status/error taxonomy with stable machine codes, safe context, retryability,
  and correlation identifiers.
- Rate/size/time limits, quotas, cache semantics, timeouts, and backpressure.
- Events/webhooks: delivery guarantee, ordering scope, signature verification,
  retries, poison handling, and schema evolution.
- Long-lived or streaming transports: connection and authentication lifetime,
  heartbeats/idle timeout, reconnect/resume cursor, duplicate or missed data,
  ordering, buffering, backpressure, fan-out, graceful drain, and intermediary
  behavior for WebSockets, Server-Sent Events, or long polling.
- Protocol details that can change semantics: HTTP version and proxy behavior,
  streaming and cancellation, gRPC deadlines/status/metadata, compression,
  connection reuse, and client or intermediary limits.

Prefer the local protocol conventions when correct. Do not import REST, GraphQL,
or eventing patterns for appearance.

## 3. Plan Compatibility And Evolution

Classify each change as additive compatible, behaviorally risky, or breaking.
Map affected consumers and generated artifacts. Choose a migration path such as
additive fields, tolerant readers, compatibility endpoint, version negotiation,
dual publish/read, or coordinated cutover.

Use Semantic Versioning only when the project defines the public surface and
what constitutes major, minor, and patch compatibility. A version number does
not make a behaviorally breaking change compatible.

Define adoption evidence, deprecation notices, sunset criteria, rollback window,
and ownership. Use `graceful-sunset-steward` for actual retirement. Never call a
change compatible only because it parses; changed meaning, defaults, ordering,
errors, performance, or authorization can break consumers.

## 4. Verify At The Boundary

Add or require:

- Schema and serialization tests, including unknown/missing/malformed values.
- Authorization and cross-scope negative tests.
- Consumer/provider contract or integration tests.
- Retry/idempotency, ordering, pagination, rate/size, and error-shape tests.
- Reconnect, resume, cancellation, slow-consumer, proxy-timeout, and graceful
  shutdown tests for long-lived or streaming connections.
- Backward/forward compatibility checks against representative old/new clients.
- Documentation/examples generated or verified against the real implementation.
- Metrics for errors, latency, saturation, version use, and deprecation progress.

## Delivery Contribution

Add the contract decision, compatibility class, consumer impact, migration plan,
boundary checks, and unresolved risks to the unified delivery record in
`GEMINI.md`.

## Hard Rules

- No breaking public change without an explicit consumer migration decision.
- No UI visibility or client filtering as a substitute for server authorization.
- No unbounded list, payload, webhook retry, or per-consumer fan-out.
- No long-lived connection without bounded buffering, lifecycle, and reconnect
  semantics.
- No invented protocol behavior; verify framework and provider semantics.

