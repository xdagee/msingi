# PLANS.md — Execution Plan Specification

> **What is this?** An Execution Plan (ExecPlan) is a living design document that a coding agent or human follows to deliver a complex feature. Use this template for any multi-hour task, significant refactor, or risky implementation.

## How to use ExecPlans

When authoring an ExecPlan, start from the skeleton below. As you research and implement, keep all sections up to date. Add or split entries in the Progress list at every stopping point to affirmatively state the progress made and next steps. 

ExecPlans are living documents — it should always be possible to restart from *only* the ExecPlan and no other work.

## Core Requirements

1. **Self-contained**: Assume the reader is a novice with no prior context. Define terms, repeat assumptions, and embed required knowledge rather than linking out.
2. **Behavior-focused**: Describe observable outcomes ("navigating to /health returns HTTP 200"), not just code changes ("added HealthCheck struct").
3. **Idempotent and safe**: Write steps so they can be run multiple times safely. Provide rollback paths for risky operations.
4. **Validation-first**: Include instructions to run tests, start the system, and observe it doing something useful. Validation is not optional.

---

# Skeleton of a Good ExecPlan

*Copy this skeleton to a new file (e.g., `docs/plans/feature-name.md`) when starting a complex task.*

## Purpose / Big Picture
Explain in a few sentences what someone gains after this change and how they can see it working. State the user-visible behavior you will enable.

## Progress
Use a list with checkboxes to summarize granular steps. Every stopping point must be documented here.
- [ ] (YYYY-MM-DD HH:MM) Example step 1.
- [ ] Example step 2.

## Surprises & Discoveries
Document unexpected behaviors, bugs, optimizations, or insights discovered during implementation. Provide concise evidence.
- **Observation:** ...
  **Evidence:** ...

## Decision Log
Record every decision made while working on the plan.
- **Decision:** ...
  **Rationale:** ...
  **Date/Author:** ...

## Context and Orientation
Describe the current state relevant to this task as if the reader knows nothing. Name the key files and modules by full path. Define any non-obvious term you will use.

## Plan of Work
Describe the sequence of edits and additions. For each edit, name the file and location and what to insert or change. Keep it concrete and minimal.

## Concrete Steps & Validation
State the exact commands to run and where to run them. When a command generates output, show a short expected transcript so the reader can compare. Describe how to start the system and what to observe.

## Outcomes & Retrospective
*(Fill this out at completion)* Summarize outcomes, gaps, and lessons learned. Compare the result against the original purpose.
