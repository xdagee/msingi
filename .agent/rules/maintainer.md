---
description: Msingi Core Maintenance and Portability 
---

# Rule: Msingi Core Maintenance

## Context
Apply this rule when modifying `msingi.ps1` (PowerShell 7) or `msingi.sh` (Bash 4+). These scripts must remain synchronized and functionally identical in their generated output.

## CRLF & Character Encoding
- Always use **CRLF (Windows)** line endings for both scripts (PS7 here-strings break on LF).
- If editing from non-Windows environments, run conversion before committing: `python3 scripts/fix_line_endings.py`.

## Here-String Invariants
- **Column 0**: Place the here-string closer (`"@`) strictly at column 0.
- **Expression Syntax**: Use `$(...)` expression patterns for all dynamic content — backtick escapes (`` `n ``, `` `t ``) break PS7 here-strings.
- **Logic**: Use `$(...)` expression patterns for all dynamic content.

## Dual-Script Parity
- **Synchronization**: Mirror every logic change in `msingi.ps1` within `msingi.sh`.
- **Byte-Identical**: Ensure `Build-*Md` functions produce byte-identical output across both platforms.

## Versioning & Metadata
- **Bump Version**: Increment the version string in both scripts for every release.
- **Sync Registry**: Coordinate version bumps with `agents.json` and `skills.json` schema updates.

## Testing & Verification
- **Full Suite**: Execute `python3 tests/test_suite.py` before every commit.
- **Strict Compliance**: Reject any commit with failed tests or syntax warnings.
