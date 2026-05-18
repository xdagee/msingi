# Gotchas: {{SKILL_NAME}}

> Each entry is a **belief with evidence** — not just a note.
> Confidence reflects how often this gotcha was triggered and whether it was ever contradicted.
> Read high-confidence entries first. They are the most likely to apply to your current task.
> This file is append-only. Do not delete entries — mark resolved ones ``[RESOLVED: date]``.

---

## Confidence scale

``●●●●● critical`` — triggered repeatedly, causes data loss or security issues, never contradicted
``●●●●○ high``     — triggered 3+ times, well-understood cause and prevention
``●●●○○ medium``   — seeded from known patterns, not yet confirmed in this project
``●●○○○ low``      — single observation, needs more evidence before trusting fully
``●○○○○ weak``     — theoretical, contradicted once, or very edge-case

> **ACE principle (arXiv 2510.04618):** each entry is a bullet with metadata.
> The ``helpful`` and ``harmful`` counters track execution feedback automatically —
> raise ``helpful`` when the gotcha prevented a real mistake; raise ``harmful``
> when following the advice led to incorrect behaviour. These counters are the
> signal that drives confidence updates. High helpful + low harmful = raise confidence.
> Low helpful + high harmful = lower confidence, investigate, possibly resolve.

---

## How to update an entry (delta update protocol)

> Do this in the gotcha delta section of SESSION.md and SKILL.md verification checklist.
> Localised updates only — never rewrite the whole file.

When a gotcha **triggers** during your session:
1. Find its entry, update ``last_seen`` to today
2. Increment ``helpful`` counter by 1
3. Raise confidence one level (max ``●●●●●``)

When a gotcha **does NOT apply** despite matching trigger keywords:
1. Find its entry, add a note: ``[date] did not apply — [why]``
2. Increment ``harmful`` counter by 1
3. Lower confidence one level (min ``●○○○○``)

When a **new failure pattern** appears that has no gotcha entry:
1. Add a new entry at the bottom of "Project-specific gotchas"
2. Start at ``●●○○○ low`` — one observation is not enough for high confidence
3. Fill ``helpful: 1``, ``harmful: 0`` to initialise counters

When a gotcha is **permanently fixed** in the codebase:
1. Mark ``status: RESOLVED (date)`` — never delete — keep as history

**New entry format (with counters):**

``````markdown
### G-NNN · [short title]
``confidence: ●●○○○ low``  ``triggers: [keywords]``  ``last_seen: [date]``  ``status: ACTIVE``
``helpful: 1``  ``harmful: 0``
**What:** [what went wrong]
**Why:** [why it happened]
**Prevention:** [how to avoid it]
``````

---

## Seeded gotchas (from known failure patterns — medium confidence until confirmed in this project)
{{SEED_BLOCK}}

---

## Project-specific gotchas

*(Add entries discovered during actual work on {{PROJECT_NAME}}.
These become the highest-value entries over time — they encode your specific project's failure history.)*

---

*File created: {{DATE}} — Msingi v{{VERSION}}*
*Confidence rises with evidence. Confidence decays when contradicted. Resolved entries stay as history.*
*Counters: helpful = times this prevented a real mistake. harmful = times following it led to wrong behaviour.*
