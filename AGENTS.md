# AGENTS.md

This file provides guidance to Qoder (qoder.com) when working with code in this repository.

## Project Overview

**Msingi** (Swahili: "foundation") is a context engineering scaffold generator. It runs as an interactive TUI, asks ~15 questions about a project, and generates the entire context infrastructure that AI agent sessions need to start from knowledge rather than exploration.

Two implementations exist in parallel:
- **msingi.ps1** — PowerShell 7, Windows, interactive TUI (~6100 lines)
- **msingi.sh** — Bash 4.4+, macOS/Linux, same output via `read` prompts (~500 lines)

Both scripts must generate **identical file content** for the same inputs. The PS7 version is the complete feature specification.

## Quick Start

```bash
# Run the tool interactively
./msingi.sh            # macOS/Linux
pwsh -File msingi.ps1  # Windows (PowerShell 7)

# Dry-run preview
./msingi.sh --dry-run
pwsh -File msingi.ps1 -DryRun
```

## Development Commands

### Syntax Validation
```bash
# Bash syntax check
bash -n msingi.sh

# PowerShell syntax check (PowerShell 7 required)
pwsh -Command "Get-Command -Syntax msingi.ps1"
```

### Testing
The test suite is referenced in documentation but not yet present in the repository. When it exists:
```bash
python3 tests/test_suite.py   # All 27 tests must pass
```

### Version Bump
Update version strings in these locations:
| File | Location | Format |
|------|----------|--------|
| `msingi.ps1` | `$VERSION` (~line 68) | `"X.Y.Z"` |
| `msingi.sh` | `VERSION` (line 11) | `"X.Y.Z"` |
| `README.md` | Badge + version history | `vX.Y.Z` |

## Architecture

### msingi.ps1 — Reading Order

The script is one file with all logic in functions. Read in this order:

1. **param() block** (line 52) — `-DryRun`, `-Update`, `-Check`, `-Path`
2. **Constants + color engine** (line 66) — ANSI true-color, `$VERSION = "3.9.0"`
3. **Terminal detection** (line 157) — `Test-Terminal`, `Validate-Data`, state management
4. **TUI primitives** (line 222+) — `Write-Header`, `Write-TwoColumn`, `Write-Splash`, `Write-Box`, `Write-Section`, `Pad`
5. **Input helpers** (line 495+) — `Read-Choice`, `Read-Checkboxes`, `Read-Line`, `Read-Confirm`
6. **Data loaders** (line 805) — `Load-Agents`, `Load-SkillPatterns`
7. **Project scan** (line 1759) — `Invoke-ProjectScan` for brownfield overlay
8. **Inference engine** (line 1862) — `Invoke-SkillInference` (two-pass: type-scope → trigger-match)
9. **Builder functions** (line 2000+) — `Build-*Md` (one per generated file, ~25 functions)
10. **MAIN section** (line 5094) — sequential screen flow (7 screens), then generation, then git

### msingi.sh — Key Differences

- No `set -e` — errors handled explicitly with `|| true`
- All `((i++))` arithmetic needs `|| true` to avoid exit under `set -uo pipefail`
- `local` keyword only inside functions — main body uses plain assignment
- `grep` inside `$()` must have `|| fallback` to handle no-match exit code
- Skill inference uses `grep -qEi` against a haystack string

### Function Naming Conventions

| Prefix | Purpose | Examples |
|--------|---------|----------|
| `Build-*` | Generate scaffold files | `Build-ContextMd`, `Build-SecurityMd` |
| `Write-*` | TUI output primitives | `Write-Header`, `Write-Box` |
| `Read-*` | Input helpers | `Read-Choice`, `Read-Confirm` |
| `Load-*` | Data loaders | `Load-Agents`, `Load-SkillPatterns` |
| `Invoke-*` | Core logic | `Invoke-SkillInference` |
| `ansi-*` | ANSI escape codes | `ansi 0` (reset) |

### Data Files

- **agents.json** — Registry of 7 supported agents (Claude Code, Gemini CLI, Codex, Opencode, Aider, Deep Agents, Antigravity). Schema v1.0.
- **skills.json** — Skill inference patterns (~70+ skills). Schema v1.0. Each skill has `id`, `name`, `category`, `types`, `baseline`, `trigger` (regex).

## Critical Constraints

### Here-String Rules (PowerShell)
- **Column 0 close**: Every closing `"@` must start at column 0 — no exceptions
- **No backtick escapes**: Never use `` `n `` or `` `t `` inside here-strings — they break PS7 parsing
- **Use `$(...)`**: For all dynamic content within here-strings

### Line Endings
- **CRLF required for msingi.ps1**: PS7 here-strings break on LF-only files
- After any edit on non-Windows: `python3 -c "p='msingi.ps1'; open(p,'wb').write(open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))"`

### Generated Output Contract
Both scripts must produce identical content:
- `CONTEXT.md` — project name, type, all agents, all skills, intake profile
- `SECURITY.md` — auth section fires only when `NeedsAuth=true`
- `gotchas.md` — confidence metadata (`●●●●●`, `triggers:`, `last_seen:`)
- `SESSION.md` — Context cost log and Token leverage note sections
- `WORKSTREAMS.md` — one workstream stub per agent with scope hints
- `bootstrap-record.json` — valid JSON with all intake fields

## What You Can and Cannot Change

### Safe to Change
- Any `Build-*Md` function body — generated content
- `Write-*` TUI helper styling
- Seeded gotchas in `Build-SkillGotchas`
- Skills in `skills.json` and agents in `agents.json`
- Evaluator pattern grading criteria in `Build-DomainMd`
- Context anxiety warning text in `Build-AgentConfig`

### Requires Care
- `Invoke-SkillInference` — changing the algorithm changes skill selection for every user
- `Read-Checkboxes` / `Read-Choice` — cursor positioning is wrap-aware; easy to break
- `Write-TwoColumn` — uses `[Console]::SetCursorPosition`; breaks if terminal is too narrow

### Never Change
- The here-string closing pattern — `"@` at column 0, no exceptions
- The CRLF requirement for PS7
- The `bootstrap-record.json` schema — downstream tools depend on it
- The three patterns from harness research (see below)

## Key Patterns from Research (v3.8.0+)

Three patterns from Anthropic's harness design research (March 2026) are baked into generated files:

1. **Sprint contract (SKILL.md)**: Agent proposes a contract mapping acceptance criteria to testable verification steps before implementing
2. **Context anxiety warning (agent configs)**: Agents told to recognize and resist premature shortcutting as context fills
3. **Evaluator pattern (DOMAIN.md)**: Documents generator-evaluator separation with grading criteria

When editing any of these sections, preserve the research attribution and behavioral instructions.

## Adding a New Skill

1. Add entry to `skills.json`:
```json
{
  "id": "kebab-case-id",
  "name": "Human Readable Name",
  "category": "auth|data|api|ui|ml|infra|messaging|testing|android",
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
- [ ] Test suite passes (when available)

## Project Philosophy

- **Offline-first**: No cloud dependencies, no API calls, no runtime requirements
- **Cross-platform**: Works on Windows (PS7), macOS/Linux (Bash 4.4+)
- **Token-aware**: Generated files are designed to minimize AI agent context costs
- **Built in Accra. Designed for everywhere.**
