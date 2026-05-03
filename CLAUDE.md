# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Msingi** (Swahili: "foundation") is a context engineering scaffold generator. It runs as an interactive TUI, asks ~15 questions about a project, and generates the entire context infrastructure that AI agent sessions need to start from knowledge rather than exploration.

Two implementations exist in parallel:
- `msingi.ps1` — PowerShell 7, Windows, interactive TUI (~6100 lines)
- `msingi.sh` — Bash 4.4+, macOS/Linux, same output via `read` prompts (~500 lines)

Both scripts must generate **identical file content** for the same inputs. The PS7 version is the complete feature specification.

## Development Commands

### Running the Tool
```bash
# Windows (PowerShell 7)
pwsh -File msingi.ps1
pwsh -File msingi.ps1 -DryRun    # Preview without writing

# macOS/Linux
./msingi.sh
./msingi.sh --dry-run
```

### Syntax Validation
```bash
# Bash syntax check
bash -n msingi.sh

# PowerShell syntax check (PowerShell 7 required)
pwsh -Command "Get-Command -Syntax msingi.ps1"
```

### Installation
```bash
# Windows
.\install.ps1

# macOS/Linux (add to PATH)
sudo ln -s "$(pwd)/msingi.sh" /usr/local/bin/msingi
```

### Version Bump
Update version strings in these locations:
| File | Location | Format |
|------|----------|--------|
| `msingi.ps1` | `$VERSION` (~line 68) | `"X.Y.Z"` |
| `msingi.sh` | `VERSION` (line 11) | `"X.Y.Z"` |
| `install.ps1` | `Get-MsingiVersion` (line 65) | `"X.Y.Z"` |
| `README.md` | Badge + version history | `vX.Y.Z` |

## Architecture — msingi.ps1

The script is one file with all logic in functions. Read in this order:

1. **param() block** (line 52) — `-DryRun`, `-Update`, `-Check`, `-Path`
2. **Constants + color engine** (line 66) — ANSI true-color, `$VERSION`
3. **Terminal detection** (line 157) — `Test-Terminal`, `Validate-Data`, state management
4. **TUI primitives** (line 222+) — `Write-Header`, `Write-TwoColumn`, `Write-Splash`, `Write-Box`, `Write-Section`, `Pad`
5. **Input helpers** (line 495+) — `Read-Choice`, `Read-Checkboxes`, `Read-Line`, `Read-Confirm`
6. **Data loaders** (line 805) — `Load-Agents`, `Load-SkillPatterns`
7. **Project scan** (line 1759) — `Invoke-ProjectScan` for brownfield overlay
8. **Inference engine** (line 1862) — `Invoke-SkillInference` (two-pass: type-scope → trigger-match)
9. **Builder functions** (line 2000+) — `Build-*Md` (one per generated file, ~25 functions)
10. **MAIN section** (line 5094) — sequential screen flow (7 screens), then generation, then git

### Function Naming Conventions

| Prefix | Purpose | Examples |
|--------|---------|----------|
| `Build-*` | Generate scaffold files | `Build-ContextMd`, `Build-SecurityMd` |
| `Write-*` | TUI output primitives | `Write-Header`, `Write-Box` |
| `Read-*` | Input helpers | `Read-Choice`, `Read-Confirm` |
| `Load-*` | Data loaders | `Load-Agents`, `Load-SkillPatterns` |
| `Invoke-*` | Core logic | `Invoke-SkillInference` |
| `ansi-*` | ANSI escape codes | `ansi 0` (reset) |

## Critical Constraints

### Here-String Rules (PowerShell)
- **Column 0 close**: Every closing `"@` must start at column 0 — no exceptions
- **No backtick escapes**: Never use `` `n `` or `` `t `` inside here-strings — they break PS7 parsing
- **Use `$(...)`**: For all dynamic content within here-strings

### Line Endings
- **CRLF required for msingi.ps1**: PS7 here-strings break on LF-only files
- After any edit on non-Windows: `python3 -c "p='msingi.ps1'; open(p,'wb').write(open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))"`

### Data Files
- **agents.json** — Registry of 7 supported agents (Claude Code, Gemini CLI, Codex, Opencode, Aider, Deep Agents, Antigravity). Schema v1.0.
- **skills.json** — Skill inference patterns (~70+ skills). Schema v1.0. Each skill has `id`, `name`, `category`, `types`, `baseline`, `trigger` (regex).
- **skills-lock.json** — Lock file for external skill dependencies with hash-based verification.

## Architecture — msingi.sh

Single Bash 4+ file. Key differences from PS7:

- No `set -e` — errors handled explicitly with `|| true`
- All `((i++))` arithmetic needs `|| true` to avoid exit under `set -uo pipefail`
- `local` keyword only inside functions — main body uses plain assignment
- `grep` inside `$()` must have `|| fallback` to handle no-match exit code
- Skill inference uses `grep -qEi` against a haystack string

## The Generated Output Contract

Both scripts must generate **identical file content** for the same inputs.
Key invariants:
- `CONTEXT.md` must contain project name, type, all agents, all skills, intake profile
- `SECURITY.md` auth section fires only when `NeedsAuth=true`
- `gotchas.md` must carry confidence metadata (`●●●●●`, `triggers:`, `last_seen:`)
- `SESSION.md` must have Context cost log and Token leverage note sections
- `WORKSTREAMS.md` must have one workstream stub per agent with scope hints
- `bootstrap-record.json` must be valid JSON with all intake fields

## Session Start — Read in This Order

1. `scratchpads/claude-code/SESSION.md` — where did the last session leave off?
2. `TASKS.md` — what is the current work?
3. This file (you are here)
4. `CONTEXT.md` — full architecture (skim unless directly relevant)

## What Agents Can and Cannot Change

### Safe to Change
- Any `Build-*Md` function body — generated content
- `Write-*` TUI helper styling
- Seeded gotchas in `Build-SkillGotchas`
- Skills in `skills.json` and agents in `agents.json`
- Sprint contract template in `Build-SkillSpec` — the criteria table structure
- Evaluator pattern grading criteria in `Build-DomainMd`
- Context anxiety warning text in `Build-AgentConfig`

### Requires Care
- `Invoke-SkillInference` — changing the algorithm changes skill selection for every user
- `Read-Checkboxes` / `Read-Choice` — cursor positioning is wrap-aware; easy to break
- `Write-TwoColumn` — uses `[Console]::SetCursorPosition`; breaks if terminal is too narrow

### Never Change
- The here-string closing pattern — `"@` at column 0, no exceptions
- The CRLF requirement — PS7 here-strings break on LF-only files
- The `bootstrap-record.json` schema — downstream tools depend on it

## Three Patterns from Harness Research (v3.8.0+)

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

## Adding a New Skill

1. Add entry to `skills.json`:
```json
{
  "id": "kebab-case-id",
  "name": "Human Readable Name",
  "category": "auth|data|api|ui|ml|infra|messaging|testing|android|core",
  "types": ["web-app", "api-service", "..."],
  "baseline": false,
  "trigger": "regex|pattern|for|matching"
}
```
2. Add gotcha seeds to `Build-SkillGotchas` in **both** `msingi.ps1` and `msingi.sh`
3. Use confidence-weighted format: `confidence: ●●●○○`, `triggers:`, `last_seen:`, `status:`

## Adding a New Agent

Add entry to `agents.json`:
```json
{
  "id": "unique-kebab-id",
  "name": "Display Name",
  "file": "FILENAME.md",
  "scratchpad": "folder-name",
  "category": "vendor|vendor-oss|oss|framework-oss",
  "repo": "https://github.com/...",
  "description": "One-line description",
  "docsUrl": "https://docs.example.com/",
  "capabilityToAct": ["file-system", "terminal", "code-execution"],
  "selfDirection": "high|medium|low",
  "roles": ["coordinator", "planner", "executor"]
}
```

Handle JSON config formats (like Opencode's `opencode.json`) as special cases in the `Build-AgentConfig` emit loop.

## Pre-Commit Checklist

- [ ] Bash syntax: `bash -n msingi.sh` passes
- [ ] PS7 here-string closers at column 0
- [ ] No backtick escapes in PS7 here-strings
- [ ] CRLF line endings for `msingi.ps1`
- [ ] Dual-script parity: both scripts produce identical output

## Reference Docs

- Claude Code: https://code.claude.com/docs/en/overview
- Bubble Tea: https://github.com/charmbracelet/bubbletea
- Lipgloss: https://github.com/charmbracelet/lipgloss
- goreleaser: https://goreleaser.com

## Additional Documentation

The `.agent/` directory contains detailed workflows and rules for Msingi development:
- `.agent/workflows/` — detailed procedures for common tasks (dual-script parity, version bump, test suite, release)
- `.agent/rules/` — platform-specific constraints and coding standards (Windows compatibility, data integrity)
- `.agent/agents/` — agent capability profiles for the generator itself
- `.agent/skills/` — skill definitions for the generator (TUI designer, automation engine, parity engine, UX engineering)

## Example Output

The `nasdh/` directory contains an example of the generated scaffold structure for reference.

## Test Suite Status

The documentation references a test suite (`python3 tests/test_suite.py`) that is planned but not yet implemented in the repository. When implemented, it will provide comprehensive validation of dual-script parity and schema compliance.
