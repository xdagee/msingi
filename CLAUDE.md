# CLAUDE.md — Msingi Development Context

> Pointer file for Claude Code working on the Msingi tool itself.
> Canonical context lives in CONTEXT.md (this repo eats its own cooking).

## What Msingi is

Msingi is a context engineering scaffold generator. It generates the foundation
every AI agent session needs to start from knowledge rather than exploration.

Two implementations exist in parallel:
- `bootstrap-agent.ps1` — PowerShell 7, Windows, interactive TUI (v3.7.0, 5000+ lines)
- `msingi.sh` — Bash 4+, macOS/Linux, same output via `read` prompts (v3.7.0)
- `msingi-go/` — Go rewrite in progress (Bubble Tea TUI, goreleaser distribution)

The PS7 and Bash versions are the **complete feature specification**.
The Go rewrite must match them exactly in generated output.

## Architecture — PS7

The script is one file. All logic is in functions. Reading order:

1. `param()` block — `-DryRun`, `-Update`, `-Check`, `-Path`
2. Constants + colour engine (ANSI true-colour)
3. TUI primitives: `Write-Header`, `Write-TwoColumn`, `Write-Splash`, `Write-Box`, etc.
4. Input helpers: `Read-Choice`, `Read-Checkboxes`, `Read-Line`, `Read-Confirm`
5. Data loaders: `Load-Agents`, `Load-SkillPatterns`
6. Inference engine: `Invoke-SkillInference` (two-pass: type-scope → trigger-match)
7. Builder functions: `Build-*Md` (one per generated file)
8. `MAIN` — sequential screen flow (7 screens), then generation, then git

## Critical constraints

**Never break here-string boundaries.** Every `@"..."@` closer must be at column 0.
Backtick escapes inside here-strings (`\`n`, `\`t`) will break PS7 parsing.
Use `$(if (...) { "text" })` patterns instead.

**CRLF line endings required.** The test suite (T21) enforces this.
After any edit: convert with `python3 -c "open('f','wb').write(open('f','rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))"`

**Version string** lives at line ~63: `$VERSION = "3.7.0"`. Bump for every release.

**Run the test suite before every commit:**
```
python3 tests/test_suite.py
```
All 27 tests must pass. The suite catches here-string imbalance, dangerous
backtick escapes, Write-Host quote parity, function brace balance, and all
feature markers from v3.0 through v3.7.

## Architecture — Bash (msingi.sh)

Single Bash 4+ file. Key differences from PS7:

- No `set -e` — errors handled explicitly with `|| true`
- All `((i++))` arithmetic needs `|| true` to avoid exit under `set -uo pipefail`
- `local` keyword only inside functions — main body uses plain assignment
- `grep` inside `$()` must have `|| fallback` to handle no-match exit code
- Skill inference uses `grep -qEi` against a haystack string

## The generated output contract

Both scripts must generate **identical file content** for the same inputs.
Key invariants:
- `CONTEXT.md` must contain project name, type, all agents, all skills, intake profile
- `SECURITY.md` auth section fires only when `NeedsAuth=true`
- `gotchas.md` must carry confidence metadata (`●●●●●`, `triggers:`, `last_seen:`)
- `SESSION.md` must have Context cost log and Token leverage note sections
- `WORKSTREAMS.md` must have one workstream stub per agent with scope hints
- `bootstrap-record.json` must be valid JSON with all intake fields

## Session start — read in this order

1. `scratchpads/claude-code/SESSION.md` — where did the last session leave off?
2. `TASKS.md` — what is the current work?
3. This file (you are here)
4. `CONTEXT.md` — full architecture (skim unless directly relevant)

## What agents can and cannot change

**Safe to change:**
- Any `Build-*Md` function body — generated content
- `Write-*` TUI helper styling
- Seeded gotchas in `Build-SkillGotchas`
- Skills in `skills.json` and agents in `agents.json`
- Tests in `tests/test_suite.py`
- Sprint contract template in `Build-SkillSpec` — the criteria table structure
- Evaluator pattern grading criteria in `Build-DomainMd`
- Context anxiety warning text in `Build-AgentConfig`

**Requires care:**
- `Invoke-SkillInference` — changing the algorithm changes skill selection for every user
- `Read-Checkboxes` / `Read-Choice` — cursor positioning is wrap-aware; easy to break
- `Write-TwoColumn` — uses `[Console]::SetCursorPosition`; breaks if terminal is too narrow

**Never change:**
- The here-string closing pattern — `"@` at column 0, no exceptions
- The CRLF requirement — PS7 here-strings break on LF-only files
- The `bootstrap-record.json` schema — downstream tools depend on it

## Three patterns from harness research (v3.8.0)

Three patterns from Anthropic's harness design research (March 2026) are baked into the generated files:

**1. Sprint contract (SKILL.md):** Before implementing any skill, the agent proposes a contract
mapping each acceptance criterion to a specific testable verification step. Saved to
`skills/<id>/assets/sprint-contract.md`. A second agent or fresh session verifies against the
contract after implementation.

**2. Context anxiety warning (agent configs):** Agents are explicitly told to recognise and resist
context anxiety — the tendency to shortcut, summarise, or wrap up prematurely as context fills.
Signs: summarising instead of implementing, skipping verification steps, writing stubs.
Fix: stop, write SESSION.md with current state, set Status: Partial.

**3. Evaluator pattern (DOMAIN.md):** Documents the generator-evaluator separation for each
project. Includes grading criteria for the project, calibration instructions, and a note
that consistent evaluator findings about stubs/shortcuts indicate generator context pressure.

When editing any of these sections, preserve the research attribution and the specific
behavioural instructions — they are the load-bearing content.

## Reference docs

- Claude Code: https://code.claude.com/docs/en/overview
- Bubble Tea: https://github.com/charmbracelet/bubbletea
- Lipgloss: https://github.com/charmbracelet/lipgloss
- goreleaser: https://goreleaser.com
