# PowerShell Standards (msingi.ps1)

Standards for Msingi's reference implementation in PowerShell 7.

## Here-String Rules
- **Column 0 Close**: Mandatory: Every closing `"@` must start at column 0.
- **Escape Rule**: Use `$(...)` expression syntax for all dynamic content — backtick escapes (`` `n ``, `` `t ``) break PS7 here-strings.
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

## Line Endings
- **CRLF Requirement**: Mandatory: All PowerShell scripts must use CRLF line endings.
- **Verification**: PS7 here-strings break if the file uses LF-only encoding.

## Function Naming
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

## Error Management
- **Preference**: Mandatory: Set `$ErrorActionPreference = "Stop"` at the script root.
- **Pattern**: Use `try/catch` blocks for all external IO or network calls.
