---
name: context-engineering
description: Use when designing or modifying the generated scaffold files (Build-*Md functions) to ensure they follow Msingi's context engineering principles.
---

# Context Engineering Skill

Design and maintain the generated scaffold files that form Msingi's core intellectual output.

## Role

You are the **Context Architect**. Your goal is to ensure every generated file maximizes agent session efficiency by following proven context engineering principles.

## Context

Msingi generates ~15 files per project. These are not documentation templates — they are a **context engineering system** designed around how AI agents actually consume information. Every section, heading, and ordering decision carries token-cost and comprehension implications.

## Instructions

1. **Static vs Dynamic Context Layers** (ML Mastery):
   - Mandatory: Explicitly separate immutable architecture/domain rules (Static) from execution state (Dynamic).
   - Agents read `SESSION.md` (Dynamic) before `CONTEXT.md` (Static).
   - Pattern: Place volatile information (status, blockers, last action) at the top of every generated file.

2. **Token Budget Rules**:
   - Mandatory: Every agent config must include context budget directives targeting a 60-80% utilization rate.
   - Constraint: `NOTES.md` must target under 300 lines; older observations use **Anchored Iterative Summarization** to compress to `NOTES-archive.md`.
   - Constraint: `SESSION.md` cost log must track tokens consumed, compression ratio, and context drift.

3. **Confidence-Weighted Gotchas**:
   - Mandatory: All gotchas use the 5-tier confidence model with Unicode circles.
   - Format: `confidence: ●●●●●` (Foundation) through `●○○○○` (Experimental).
   - Required Fields: `triggers:`, `last_seen:`, `status:` on every gotcha entry.

4. **Sprint Contract Pattern** (Research v3.8.0+):
   - Mandatory: Every `SKILL.md` contains a sprint contract section where agents map acceptance criteria to testable verification steps before implementing.
   - Preservation: Preserve the research attribution from Anthropic's harness design research.

5. **Context Anxiety Warning** (Research v3.8.0+):
   - Mandatory: Every agent config includes the context anxiety warning — agents must recognise and resist premature shortcutting as context fills.
   - Signs: summarising instead of implementing, skipping verification steps, writing stubs.
   - Fix: stop, write SESSION.md with current state, set Status: Partial.

6. **Probe-Based Evaluation** (ML Mastery):
   - Mandatory: Agents must explicitly state their architectural assumptions and probe retrieved context to verify them before executing complex logic.
   - Include `<probe_based_evaluation>` XML hooks in agent configurations.

7. **Context Drift Detection** (ML Mastery):
   - Mandatory: `SESSION.md` logs must include an explicit check to verify if the current execution is still aligned with the original milestone.

8. **Evaluator Pattern** (Research v3.8.0+):
   - Mandatory: `DOMAIN.md` documents the generator-evaluator separation with grading criteria.
   - Pattern: Consistent evaluator findings about stubs/shortcuts indicate generator context pressure.

9. **Generated Output Invariants**:
   - `CONTEXT.md`: Must contain project name, type, all agents, all skills, intake profile.
   - `SECURITY.md`: Auth section fires only when `NeedsAuth=true`.
   - `WORKSTREAMS.md`: One workstream stub per agent with scope hints.
   - `bootstrap-record.json`: Must be valid JSON with all intake fields.

## Safe-to-Modify Areas

- Any `Build-*Md` function body — generated content
- Seeded gotchas in `Build-SkillGotchas`
- Sprint contract template structure in `Build-SkillSpec`
- Evaluator grading criteria in `Build-DomainMd`
- Context anxiety warning text in `Build-AgentConfig`

## Preservation Requirements

- Preserve the three research patterns' behavioural instructions — they are load-bearing content
- Preserve the `bootstrap-record.json` schema — downstream tools depend on it
- Preserve the confidence tier format (`●●●●●` through `●○○○○`)
