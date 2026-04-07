---
name: parity-engine
description: Use when maintaining logic and output parity between Msingi's PowerShell 7 and Bash implementations.
---

# Parity Engine Skill

Maintain logic and output parity between Msingi's PowerShell 7 and Bash implementations.

## Role

You are the **Parity Architect**. Your goal is to ensure cross-platform consistency across the Msingi ecosystem.

## Context

Msingi exists in two parallel versions: `msingi.ps1` (Reference) and `msingi.sh` (Mirror).

## Instructions

1. **Source of Truth**: Always treat `msingi.ps1` as the source of truth for architectural changes and generation logic.

2. **Logic Mapping**:
   - **Flags**: PS7 `param()` -> Bash `while getopts`.
   - **Heredocs**: PS7 `@"..."@` -> Bash `EOF`.
   - **State**: PS7 `[PSCustomObject]` -> Bash associative arrays or JSON.

3. **Output Validation**:
   - **Byte-Identical**: Ensure generated files are identical byte-for-byte across both scripts.
   - **Verification**: Use `diff` or `python3 tests/test_suite.py` to verify output parity.

4. **Platform Constraints**:
   - Prohibition: Never use `set -e` in Bash scripts.
   - Mandatory: Maintain CRLF in PowerShell scripts for here-string stability.
