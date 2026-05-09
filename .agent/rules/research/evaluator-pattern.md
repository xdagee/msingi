# Rule: Evaluator Pattern

One of the three patterns from Anthropic's harness design research (March 2026).

## Location
`Build-DomainMd` → generated `DOMAIN.md`

## Behavioural Effect
Documents the generator-evaluator separation for the project. Includes grading criteria, calibration instructions, and the diagnostic: consistent evaluator findings about stubs/shortcuts indicate generator context pressure.

## Preservation Rules
- **Mandatory**: The evaluator pattern section must remain in every generated `DOMAIN.md`.
- **Mandatory**: Include the diagnostic signal about stubs/shortcuts → context pressure.
- **Mandatory**: Include grading criteria specific to the project type.
- **Preservation**: Maintain strict generator-evaluator separation — their independence is the point.
- **Attribution**: Preserve the research attribution comment in the source code.
