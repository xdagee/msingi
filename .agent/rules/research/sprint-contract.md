# Rule: Sprint Contract

One of the three patterns from Anthropic's harness design research (March 2026).

## Location
`Build-SkillSpec` → generated `skills/<id>/SKILL.md`

## Behavioural Effect
Before implementing any skill, the agent proposes a contract mapping each acceptance criterion to a specific testable verification step. A second agent or fresh session verifies against the contract after implementation.

## Preservation Rules
- **Mandatory**: The sprint contract section must remain in every generated `SKILL.md`.
- **Mandatory**: The contract must map acceptance criteria → verification steps (not just list criteria).
- **Preservation**: Maintain the full criteria-to-verification mapping — the mapping structure is the load-bearing element.
- **Attribution**: Preserve the research attribution comment in the source code.
