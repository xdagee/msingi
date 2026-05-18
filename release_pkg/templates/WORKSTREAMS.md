# WORKSTREAMS.md — Parallel Agent Coordination

**Project:** {{PROJECT_NAME}}
**Type:** {{PROJECT_TYPE_LABEL}}
**Created:** {{DATE}}

> Karpathy principle: the skill is now how to manage a small org of agents.
> Carve the codebase into parallel non-conflicting workstreams.
> Each workstream owns a defined scope. Agents do not write outside their scope.
> Human reviews at merge checkpoints — not after every commit.

---

## Why workstreams matter

Without scope boundaries, parallel agents create conflicts:
- Two agents modify the same file simultaneously → merge chaos
- Agent A makes assumptions about Agent B's output → silent incompatibility
- No checkpoint → problems discovered late when they are expensive to fix

Workstreams prevent this. Each agent has exclusive write access to its scope.
Read access is unrestricted — agents can read anything.

---

## Coordination rules

1. **Scope is exclusive write, unrestricted read.**
   An agent may read any file. It may only write to files within its assigned scope.

2. **Declare conflicts before starting.**
   If two workstreams need to write the same file, resolve ownership before starting.
   One agent owns the file; the other proposes changes via a PR or a spec update.

3. **Phase gates before parallel work.**
   Some work must be sequential. Define phases below.
   Example: auth schema (WS-1) must be confirmed before API layer (WS-2) starts.

4. **Merge checkpoints are mandatory.**
   A workstream does not merge until all its checkpoint criteria pass.
   The human reviews at merge — agents do not self-approve merges.

5. **SESSION.md is per-agent, WORKSTREAMS.md is shared.**
   Update this file when workstream status changes.
   It is the single view of parallel progress.

---

## Phases (define before starting parallel work)

| Phase | Workstreams | Gate to advance |
|-------|-------------|-----------------|
| 1 — Foundation | *(e.g. WS-1: schema + auth)* | Schema confirmed, auth contract signed off |
| 2 — Core build | *(e.g. WS-2, WS-3 in parallel)* | Phase 1 merged and green |
| 3 — Integration | *(all workstreams)* | All scopes merged, integration tests pass |

*(Edit phases to match your actual delivery plan. Delete rows that do not apply.)*

---

## Workstreams
{{WORKSTREAM_DEFINITIONS}}
---

## Conflict log

| Date | File | WS-A | WS-B | Resolution |
|------|------|------|------|------------|
| *(add when a conflict is discovered and resolved)* | | | | |

---

## Merge history

| Date | Workstream | What merged | Reviewer |
|------|------------|-------------|----------|
| {{DATE}} | — | Initial scaffold | Msingi v{{VERSION}} |

---

*Update this file at every merge checkpoint and whenever scope changes.*
*Scope changes require human approval — agents do not reassign scope unilaterally.*
