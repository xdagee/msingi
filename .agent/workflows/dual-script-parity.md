---
description: Verify PowerShell and Bash scripts produce identical output
---

# Workflow: Dual-Script Parity

This workflow ensures `msingi.ps1` and `msingi.sh` generate byte-identical output for the same inputs.

## When to Use

- After editing `msingi.ps1`
- After editing `msingi.sh`
- Before any commit that modifies either script

## Procedure

### 1. Verify PowerShell Syntax
```powershell
pwsh -Command "Get-Command -Syntax msingi.ps1"
```

### 2. Verify Bash Syntax
```bash
bash -n msingi.sh
```

### 3. Run Full Test Suite
```bash
python3 tests/test_suite.py
```

All 27 tests must pass.

### 4. Manual Output Comparison (if needed)

Generate test output from both scripts and compare:

```powershell
# PowerShell: Generate test scaffold
$outputPS = & .\msingi.ps1 -DryRun -Path .\test-scaffold-ps

# Bash: Generate test scaffold  
$outputBash = & bash msingi.sh --dry-run

# Compare (files should be identical)
diff -r test-scaffold-ps test-scaffold-bash
```

## Common Parity Issues

| Issue | PS7 | Bash |
|-------|-----|------|
| Here-string | `"@` at column 0 | N/A |
| Date format | `Get-Date` | `date` command |
| Path handling | `Join-Path` | `$()``pwd``/path` |
| Array indexing | `$arr[0]` | `${arr[0]}` |
| Case sensitivity | `-eq` (case-insensitive) | Use `[[:upper:]]` |

## Rollback

If parity breaks:
1. Identify which script changed
2. Revert to last known good state: `git checkout HEAD -- msingi.ps1`
3. Re-apply changes with parity in mind
4. Re-run test suite

---
*Part of Msingi Development Workflows*
