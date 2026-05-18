# DISCOVERY.md — Exploration & Experiments Log

**Project:** {{PROJECT_NAME}}
**Type:** {{PROJECT_TYPE_LABEL}}

> Pattern 3 of AI-native development: the bottleneck shifts from *delivery* to *discovery*.
> When generation is cheap, the valuable work is evaluating variants — not executing one.
> This file tracks approaches explored, prototypes attempted, and decisions about direction.
> It is distinct from memory/decisions/ (which records confirmed architectural choices).

---

## What belongs here

- Alternative approaches considered but not yet decided
- Prototype results: what was tried, what it revealed, why it was abandoned or adopted
- Experiments: hypothesis, method, outcome
- Variant comparisons: A vs B analysis before committing

## What does not belong here

- Confirmed architectural decisions → memory/decisions/
- Implementation tasks → TASKS.md
- Context drift corrections → CHANGELOG.md

---

## How to use

**Before starting a significant feature:**
Add an entry describing the approach you are about to try and your hypothesis.

**After attempting something:**
Record the outcome — even if it failed. Failures are the most valuable entries.

**When comparing approaches:**
Document both. Record which you chose and why. Link to the ADR in memory/decisions/ if a decision was confirmed.

---

## Exploration log

### {{DATE}} — Project initialisation

**Question:** What is the right scaffold structure for {{PROJECT_NAME}}?
**Approach:** Msingi v{{VERSION}} — {{PROJECT_TYPE_LABEL}} scaffold with context engineering.
**Hypothesis:** A canonical CONTEXT.md + skill specs + decision log will prevent context drift across agent sessions.
**Status:** In progress — evaluate after 3 sessions.
**Next:** After first milestone, assess whether skill specs reduced implementation loops.

---

<!-- Entry template:

### YYYY-MM-DD — [short title]

**Question:** [What are you trying to find out?]
**Approach:** [What you tried — be specific enough to reproduce]
**Hypothesis:** [What you expected and why]
**Outcome:** [What actually happened]
**Learned:** [What this tells you — even null results are useful]
**Status:** EXPLORING | ABANDONED | ADOPTED | SUPERSEDED
**Link:** [ADR in memory/decisions/ if this led to a confirmed decision]

-->
