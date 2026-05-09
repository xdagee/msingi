# Rule: Coding Standards

Core standards for Msingi development, ensuring cross-platform stability and TUI excellence.

## Summary

Msingi is a cross-platform TUI tool where PowerShell 7 is the reference implementation and Bash 4+ is the mirrored implementation. All development must adhere to strict platform-specific standards and parity rules.

## Standard Modules (Pointer Hub)

- [**PowerShell Standards**](coding/powershell.md) — Here-strings, CRLF, naming, error handling.
- [**Bash Standards**](coding/bash.md) — Error mode, variable scope, pattern matching.
- [**JSON Standards**](coding/json.md) — Schema v1.0, root keys, ID conventions.
- [**Synchronization & Verification**](coding/synchronization.md) — Dual-script parity, version bumps, syntax checks.

## Scope
- **Scripts**: `msingi.ps1`, `msingi.sh`, and `Install.ps1`
- **Data**: `agents.json` and `skills.json`

## Metadata
- **Maintainer**: Msingi Maintainer
- **Schema Version**: 1.0
- **Status**: Stable
