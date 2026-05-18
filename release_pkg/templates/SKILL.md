---
allowed-tools: [read_file, grep_search, list_dir, write_to_file, run_command]
---

# {{SKILL_NAME}}

> **When to use:** {{TRIGGER}}

**ID:** {{SKILL_ID}}  **Category:** {{CATEGORY}}  **Status:** UNIMPLEMENTED  **Created:** {{DATE}}

---

## Quick start
> Read this section first. Load the rest of the spec only when you need the detail.
> This is the minimum context to begin implementing correctly.

{{QS}}

**Before writing any code:** read ``gotchas.md`` and ``evals/EVAL.md`` in this folder.
Start with ``●●●●●`` and ``●●●●○`` entries — they are the most likely to apply.
**After implementing:** write a compact result record to ``outputs/``, update ``last_seen`` on any gotcha that triggered, and add new entries for anything unexpected.

---

> This is a contract, not an implementation plan.
> Status lifecycle: UNIMPLEMENTED → IN PROGRESS → NEEDS-REVIEW → IMPLEMENTED
> Any deviation from the Interface section must be logged in memory/decisions/.

---

## Skill folder contents

| File | Purpose |
|------|---------|
| ``SKILL.md`` | This file — the contract |
| ``gotchas.md`` | Failure patterns accumulated from real usage — read before implementing |
| ``evals/EVAL.md``| **Definition of success** — define happy/edge/neighbor cases before code |
| ``config.json`` | First-run setup, local overrides, and runtime status |
| ``scripts/`` | Purpose-built scripts Claude can run (Utility Bundle pattern) |
| ``assets/`` | Templates, reference data, and intermediate plans |
| ``references/`` | API docs, type definitions, detailed specs |
| ``outputs/`` | Structured results from skill executions — compressed context |

**Progressive disclosure:** Read ``SKILL.md`` first. Fetch other files only when you need the detail.
**Eval-First:** Write evaluations to ``evals/EVAL.md`` before writing implementation code.
**Plan-Validate-Execute:** Insert a verifiable plan (saved to ``assets/plan.json``) before any destructive or batch operation.

---

## Purpose

One sentence: what this skill does and why it exists in **{{PROJECT_NAME}}**.

*Project context: "{{SHORT_DESC}}"*

---

## Interface

### Inputs
| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| — | — | — | — | Define before implementing |

### Outputs

**Success:**
``````
{ success: true, data: <define shape here> }
``````

**Error:**
``````
{ success: false, error: { code: string, message: string, details?: object } }
``````

### Side effects
<!-- DB writes, cache invalidations, events emitted, external API calls. Be explicit. -->

- *(none defined yet)*

---

## Examples
<!-- Calibration for style, tone, and formatting (In-Skill Examples pattern). -->

### Example 1
**Input:**
```
[describe input]
```
**Output:**
```
[describe desired output]
```

---

## Constraints

{{HINT}}

### Guardrails (Explain-the-Why)
- **Do not swallow errors silently.** If errors are swallowed, we lose the visibility needed to debug production failures and the system may enter an inconsistent state.
- **Validate all inputs at the boundary.** Unvalidated input is the primary source of injection attacks and malformed data in the persistence layer.
- **Avoid blocking the main thread for I/O.** Blocking the event loop causes latency spikes that degrade user experience and throughput.

### Acceptance criteria
- [ ] Happy path: *(define the expected successful flow)*
- [ ] Auth failure: *(define behaviour when caller is not authorised)*
- [ ] Validation failure: *(define behaviour on bad input)*
- [ ] Downstream failure: *(define behaviour when external dependency fails)*
- [ ] Performance: *(define latency or throughput target)*

---

## Execution Checklist
<!-- Linear workflow for multi-step procedures (Execution Checklist pattern). -->
<!-- Copy these into your response and tick them off as you progress. -->

- [ ] 1. Pre-execution verification (check state, dependencies)
- [ ] 2. Core implementation step A
- [ ] 3. Core implementation step B
- [ ] 4. Post-execution validation (verify side effects, run tests)

---

## Sprint contract (Plan-Validate-Execute)

> Before writing implementation code, the agent proposes a contract here.
> This bridges the gap between the high-level spec and the testable reality.
> For quality-critical tasks, use a **Self-Correcting Loop**: produce output,
> run a validator, fix if needed, and only then declare completion.

**Status:** [ ] Not started  [ ] Plan proposed  [ ] Plan confirmed  [ ] In progress  [ ] Done

### What will be built
*(Describe the specific implementation plan. If batch/destructive, reference assets/plan.json)*


### How it will be verified
*(Map each acceptance criterion above to a concrete, testable verification step)*

