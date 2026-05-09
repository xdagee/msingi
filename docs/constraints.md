# Critical Constraints

Msingi has strict technical constraints to ensure dual-script parity and PowerShell 7 stability.

## PowerShell Here-Strings
- **Column 0 Close**: Every closing `"@` must start at column 0.
- **No Backtick Escapes**: Never use `` `n `` or `` `t `` inside here-strings; use `$(...)` for dynamic content.

## Line Endings
- **CRLF Requirement**: `msingi.ps1` **must** use CRLF line endings.
- **Conversion**: On non-Windows systems, use `python3 -c "p='msingi.ps1'; open(p,'wb').write(open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))"`.

## Function Naming
| Prefix | Purpose | Examples |
|--------|---------|----------|
| `Build-*` | Generate scaffold files | `Build-ContextMd` |
| `Write-*` | TUI output primitives | `Write-Header` |
| `Read-*` | Input helpers | `Read-Choice` |
| `Load-*` | Data loaders | `Load-Agents` |
| `Invoke-*` | Core logic | `Invoke-SkillInference` |
| `ansi-*` | ANSI escape codes | `ansi-fg` |
