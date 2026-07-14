---
name: code-archaeologist
description: Use before modifying unfamiliar existing code, debugging, or accepting non-trivial AI-generated code. Prevents write-first behavior by proving the agent understands callers, contracts, state, and failure modes.
---

# Code Archaeologist

Engage when:

- You did not create the code and the change is more than trivial.
- You are changing behavior in a file you have not read.
- You are fixing a bug in unfamiliar code.
- You are reviewing or accepting non-trivial generated code.
- The file is load-bearing: business rules, security, data integrity, concurrency, migrations, or public API.

Do not write durable implementation code until comprehension is sufficient for the risk.

## Step 1: Map The Territory

Identify:

- Entry points: routes, handlers, jobs, commands, event listeners, UI flows.
- Callers and callees: who depends on this and what it depends on.
- Data flow: input, parsing, transformation, persistence, output.
- Public contract: types, return values, errors, side effects, events, logs.
- Ownership: module, bounded context, feature area, or subsystem.
- Invariants: what must be true before, during, and after execution.

## Step 2: Read The Local Narrative

Inspect nearby evidence:

- Tests, fixtures, snapshots, examples, stories, docs, ADRs, comments.
- Existing helpers and conventions for validation, errors, transactions, logging, and naming.
- Git history or blame when available and useful. If no Git history exists, do not invent it.

## Step 3: Classify The Code

- **Load-bearing:** business rules, auth, data integrity, concurrency, persistence, public contracts. Touch cautiously.
- **Boundary code:** parsing, adapters, controllers, queues, integrations. Protect contracts and failures.
- **Scaffolding:** presentation glue, simple mapping, local formatting. Safer, but still preserve conventions.
- **Dead or unclear:** do not remove without evidence.

If you cannot explain why a suspicious line exists, treat it as intentional until proven otherwise.

## Step 4: Predict Effects

Before editing, be able to answer:

- What callers observe today.
- What behavior changes after the edit.
- What state could be corrupted, leaked, duplicated, or lost.
- What failures become more or less likely.
- What tests/checks should catch a bad change.
- What the smallest safe rollback would be.

## Output

```
Code archaeology: COMPLETE | PARTIAL | BLOCKED
Files/context inspected: [...]
Contracts/invariants found: [...]
Uncertain inferences: [...]
Risk: BLOCKER | WARNING | NOTE - [...]
```

## Hard Rules

- Never modify durable code you cannot explain at the level required by the risk.
- Never accept an abstraction with unclear ownership or contract.
- Never remove code only because it looks unused; prove it or leave it.
- "Ask the AI again" is not comprehension.
