# Msingi Architecture

Msingi is built as a dual-script scaffolding engine with a focus on cross-platform TUI consistency.

## msingi.ps1 — PowerShell 7 Reference

The PowerShell script is the primary reference implementation. It is structured for sequential execution with logic encapsulated in functions.

### Reading Order
1. **param() block** (line 52) — CLI parameters.
2. **Constants + color engine** (line 66) — ANSI true-color and metadata.
3. **Terminal detection** (line 157) — validation and state management.
4. **TUI primitives** (line 222+) — `Write-*` functions for terminal UI.
5. **Input helpers** (line 495+) — `Read-*` functions for interactive prompts.
6. **Data loaders** (line 805) — loading `agents.json` and `skills.json`.
7. **Inference engine** (line 1762) — skill detection logic.
8. **Builder functions** (line 1900+) — `Build-*Md` functions for file generation.
9. **MAIN section** (line 4994) — execution flow.

## msingi.sh — Bash 4.4+ Mirror

The Bash script mirrors the PS7 logic with specific adjustments for shell compatibility:
- Explicit error handling with `|| true`.
- Local variable scoping inside functions.
- Fallback logic for `grep` operations.
- Regex-based skill inference.

## Data Schema
- **agents.json**: Agent registry with capabilities and roles.
- **skills.json**: Skill inference patterns (regex).
- **skills-lock.json**: Hash-based verification for skill dependencies.
