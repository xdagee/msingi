---
description: Preservation rules for the three Anthropic harness research patterns baked into Msingi v3.8.0+
---

# Rule: Research Pattern Preservation

Governs the three patterns from Anthropic's harness design research (March 2026) that are baked into Msingi's generated files.

## Scope

- **Functions**: `Build-SkillSpec`, `Build-AgentConfig`, `Build-DomainMd`
- **Output files**: `SKILL.md`, agent config files, `DOMAIN.md`
- **Subagents**: All — these patterns apply to every agent working on Msingi

## Metadata

- **Maintainer**: Foundation Maintainer
- **Status**: Stable — Never Modify Without Review
- **Research Origin**: Anthropic harness design research, March 2026

## Context

Three patterns derived from Anthropic's research into agent harness design are embedded in Msingi's generated files. These are not decorative documentation — they are **behavioural instructions** that change how AI agents operate. Removing or weakening them degrades agent session quality.

## Pattern 1: Sprint Contract (SKILL.md)

### Location
`Build-SkillSpec` → generated `skills/<id>/SKILL.md`

### Behavioural Effect
Before implementing any skill, the agent proposes a contract mapping each acceptance criterion to a specific testable verification step. A second agent or fresh session verifies against the contract after implementation.

### Preservation Rules
- **Mandatory**: The sprint contract section must remain in every generated `SKILL.md`.
- **Mandatory**: The contract must map acceptance criteria → verification steps (not just list criteria).
- **Preservation**: Maintain the full criteria-to-verification mapping — the mapping structure is the load-bearing element.
- **Attribution**: Preserve the research attribution comment in the source code.

## Pattern 2: Context Anxiety Warning (Agent Configs)

### Location
`Build-AgentConfig` → generated `agents/<AGENT>.md`

### Behavioural Effect
Agents are explicitly told to recognise and resist context anxiety — the tendency to shortcut, summarise, or wrap up prematurely as the context window fills.

### Signs of Context Anxiety
- Summarising instead of implementing
- Skipping verification steps
- Writing stubs instead of complete implementations
- Declaring "done" without testing

### Fix Protocol
- Stop immediately
- Write `SESSION.md` with current state
- Set `Status: Partial`
- Document what remains

### Preservation Rules
- **Mandatory**: The context anxiety warning must appear in every generated agent config.
- **Mandatory**: Include both the signs and the fix protocol — agents need both recognition and remediation.
- **Preservation**: Maintain direct, imperative phrasing — the tone is intentional and research-backed.
- **Attribution**: Preserve the research attribution comment in the source code.

## Pattern 3: Evaluator Pattern (DOMAIN.md)

### Location
`Build-DomainMd` → generated `DOMAIN.md`

### Behavioural Effect
Documents the generator-evaluator separation for the project. Includes grading criteria, calibration instructions, and the diagnostic: consistent evaluator findings about stubs/shortcuts indicate generator context pressure.

### Preservation Rules
- **Mandatory**: The evaluator pattern section must remain in every generated `DOMAIN.md`.
- **Mandatory**: Include the diagnostic signal about stubs/shortcuts → context pressure.
- **Mandatory**: Include grading criteria specific to the project type.
- **Preservation**: Maintain strict generator-evaluator separation — their independence is the point.
- **Attribution**: Preserve the research attribution comment in the source code.

## Editing Guidelines

When modifying any section containing these patterns:

1. **Read the pattern description** above to understand what it does behaviourally.
2. **Preserve the research attribution** — the comment linking to Anthropic's harness research.
3. **Preserve the behavioural instructions** — these are the load-bearing content, not the surrounding markdown.
4. **Test with a fresh agent session** — verify the agent follows the pattern after your edit.
5. **Request review** — any change to these patterns requires explicit approval.
