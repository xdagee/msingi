# Rule: Context Anxiety Warning

One of the three patterns from Anthropic's harness design research (March 2026).

## Location
`Build-AgentConfig` → generated `agents/<AGENT>.md`

## Behavioural Effect
Agents are explicitly told to recognise and resist context anxiety — the tendency to shortcut, summarise, or wrap up prematurely as the context window fills.

## Signs of Context Anxiety
- Summarising instead of implementing
- Skipping verification steps
- Writing stubs instead of complete implementations
- Declaring "done" without testing

## Fix Protocol
- Stop immediately
- Write `SESSION.md` with current state
- Set `Status: Partial`
- Document what remains

## Preservation Rules
- **Mandatory**: The context anxiety warning must appear in every generated agent config.
- **Mandatory**: Include both the signs and the fix protocol — agents need both recognition and remediation.
- **Preservation**: Maintain direct, imperative phrasing — the tone is intentional and research-backed.
- **Attribution**: Preserve the research attribution comment in the source code.
