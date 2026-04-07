# Rule: Coding Standards

Standards for Msingi development, ensuring cross-platform stability and TUI excellence.

## Scope
- **Scripts**: `msingi.ps1`, `msingi.sh`, and `Install.ps1`
- **Data**: `agents.json` and `skills.json`

## Metadata
- **Maintainer**: Msingi Maintainer
- **Schema Version**: 1.0
- **Status**: Stable

## Context
Msingi is a cross-platform TUI tool where PowerShell 7 is the reference implementation and Bash 4+ is the mirrored implementation.

## PowerShell Standards (msingi.ps1)

### Here-String Rules
- **Column 0 Close**: Mandatory: Every closing `"@` must start at column 0.
- **Escape Prohibition**: Prohibition: Never use backtick escapes (`` `n ``, `` `t ``) inside here-strings.
- **Expression Syntax**: Mandatory: Use `$(...)` for all dynamic content within here-strings.

```powershell
# Good
$data = @"
Item: $($item.name)
"@

# Bad - backtick escape
$data = @"
Item: `$($item.name)
"@
```

### Line Endings
- **CRLF Requirement**: Mandatory: All PowerShell scripts must use CRLF line endings.
- **Verification**: PS7 here-strings break if the file uses LF-only encoding.

### Function Naming
- **Prefix Standards**: Mandatory: Use only approved prefixes in `PascalCase`.

| Prefix | Purpose | Examples |
|--------|---------|----------|
| `Build-*` | Generate scaffold files | `Build-ContextMd` |
| `Write-*` | TUI output primitives | `Write-Header` |
| `Read-*` | Input helpers | `Read-Choice` |
| `Load-*` | Data loaders | `Load-Agents` |
| `Invoke-*` | Core logic | `Invoke-SkillInference` |
| `ansi-*` | ANSI escape codes | `ansi-fg` |
| `cursor-*` | Cursor control | `cursor-pos` |

### Error Management
- **Preference**: Mandatory: Set `$ErrorActionPreference = "Stop"` at the script root.
- **Pattern**: Use `try/catch` blocks for all external IO or network calls.

## Bash Standards (msingi.sh)

### Error Handling
- **Mode Prohibition**: Prohibition: Never use `set -e`.
- **Explicit Handling**: Mandatory: Handle errors explicitly with `|| true` on optional steps.
- **Arithmetic**: Mandatory: All `((i++))` arithmetic must be followed by `|| true`.

```bash
# Good
((i++)) || true

# Bad - will cause exit under some shells
((i++))
```

### Variable Scope
- **Local Scope**: Mandatory: Use `local` for all variables inside functions.
- **Global Scope**: Use plain assignment in the main body.

### Pattern Matching
- **Fallback Logic**: Mandatory: All `grep` operations inside `$()` must have an `|| echo ""` fallback.
- **Flags**: Mandatory: Use `grep -qEi` for silent, case-insensitive matching.

## JSON Standards (Schema v1.0)

### Mandatory Structure
- **Root Key**: Mandatory: Both `agents.json` and `skills.json` must have a root-level `"schema_version": "1.0"`.
- **Nested Arrays**: Mandatory: Content must reside in nested `agents` or `skills` arrays.

### ID Conventions
- **Format**: Mandatory: kebab-case only.
- **Length**: Prohibition: IDs must not exceed 40 characters.

## Synchronization Rules

### Dual-Script Parity
- **Byte-Identical**: Mandatory: Every `Build-*` function must produce identical output byte-for-byte between both scripts.
- **Mirrored Logic**: Mandatory: Every logic change in `msingi.ps1` must be mirrored in `msingi.sh` before check-in.

### Automated Verification
- **Test Suite**: Mandatory: Run `python -m pytest tests/test_navigation.py` before committing any TUI changes.
- **Syntax Check**: Mandatory: Run `bash -n msingi.sh` after any Bash edit.
