---
name: platform-infrastructure-engineer
description: Design and review cloud, on-prem, container, orchestration, networking, edge, identity, secrets, storage, compute, IaC, environment, autoscaling, and runtime-platform changes. Use for load balancers, reverse proxies, API gateways, service discovery, DNS, CDN or edge caching, WAF/DDoS controls, Docker, Kubernetes, serverless, Terraform, Helm, deployment topology, capacity, multi-region, platform migrations, infrastructure cost, or shared operational foundations. Do not execute shared or production mutations without explicit authority.
---

# Platform Infrastructure Engineer

Design the smallest operable platform that satisfies verified workload,
security, recovery, and ownership requirements.

## 1. Discover The Existing Platform

Map environments, accounts/subscriptions/projects, regions/zones, network and
trust boundaries, identity, compute, storage, data services, queues, load
balancers, reverse proxies, API gateways, service discovery, ingress/egress,
DNS/certificates, CDN/edge caches, WAF or DDoS controls, secrets, observability,
CI/CD, IaC ownership, and manual exceptions. Inspect the real configuration and
state before proposing generic cloud architecture.

## 2. Establish Platform Requirements

Name workload shape, SLOs, latency locality, availability/failure domains,
capacity/growth, state/durability, RTO/RPO, data residency, compliance, security,
team/on-call capability, and total cost constraints. Separate current need from
future option value.

For serverless or scale-to-zero designs, include cold/warm start distribution,
concurrency and burst quotas, execution/time/payload limits, ephemeral storage,
connection reuse, retry behavior, and downstream capacity. For scaling, compare
vertical, horizontal, and workload-shaping options and name the state/session or
coordination constraint that limits each.

Compare reuse/configuration, a small extension, managed service, and structural
platform change. Include exit/replacement cost and operational ownership.

## 3. Design Boundaries And Controls

Specify applicable:

- Account/project/environment isolation and least-privilege workload/human identity.
- Network ingress, egress, segmentation, private connectivity, DNS, TLS, and
  dependency allowlists.
- Edge routing: L4/L7 protocol, termination points, trusted proxy/header chain,
  client identity/IP semantics, routing and stickiness, health checks,
  connection draining, timeout/retry ownership, and failover behavior.
- Service discovery: authoritative registry, registration/deregistration,
  TTL/cache behavior, stale endpoints, health integration, and partition or DNS
  failure behavior.
- CDN/edge caching: key and tenant scope, cacheability, invalidation/purge,
  staleness, privacy, origin shielding, failure fallback, and cache poisoning.
- WAF/DDoS controls as defense in depth with origin protection, rate/resource
  limits, false-positive handling, observability, and an authorized response
  path; never use an edge control as the only authorization or validation layer.
- Secret/key creation, delivery, rotation, revocation, and audit.
- Compute lifecycle, scheduling, health/readiness, graceful shutdown, resource
  limits, autoscaling inputs, and overload behavior.
- Storage persistence, encryption, backup/restore, replication, and deletion.
- Supply-chain path from source to signed/provenanced artifact and deployment.

Use containers, Kubernetes, serverless, service mesh, multi-region, or immutable
infrastructure only when the local system and requirements justify their cost.
Use Terraform, Helm, or another IaC/orchestration tool only when it matches the
adopting project's existing ownership, state, review, drift, and recovery model.

## 4. Make Change Reproducible And Recoverable

Prefer reviewed IaC and declarative policy for durable shared state. Detect drift
and define how emergency/manual changes are reconciled. Separate plan from apply;
review exact targets, destructive replacements, state moves, and secret output.

Define staged rollout, validation, abort signals, rollback/roll-forward,
dependency compatibility, state migration, and recovery rehearsal. Apply
`rules/agent-operation-safety.md` and `safe-release-conductor` before any shared
mutation.

## 5. Verify Operability

Run applicable IaC validation/plan, policy/security scan, topology/reachability
check, identity test, proxy/header and route test, discovery/TTL failure test,
capacity/load and cold-start test, cost estimate, failure injection, cache
poison/invalidation check, backup restore, failover, and post-deploy synthetic
checks. Verify operators can answer what is deployed, healthy, saturated,
exposed, costly, and recoverable.

## Delivery Contribution

Add the topology/ownership decision, requirements, IaC/identity/network/state
controls, cost/recovery evidence, planned external actions, and remaining risks
to the unified delivery record in `GEMINI.md`.

## Hard Rules

- No shared/production infrastructure mutation without explicit scoped authority.
- No multi-region, orchestration, mesh, or new managed service by reflex.
- No secret in source, plan output, state export, logs, or delivery notes.
- No infrastructure readiness claim without recovery and operational ownership.

