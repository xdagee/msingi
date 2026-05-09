---
description: Windows-specific environment and pathing constraints
---

# Rule: Windows Compatibility

This document defines Windows-specific constraints for Msingi development.

## Path Formats & Separation

### PowerShell 7
- **Backslashes**: Always use the backslash `\` separator for file system paths.
- **Construction**: Use `Join-Path` for all dynamic path building.
- **Relative Paths**: Prefer relative paths from `$PSScriptRoot`.

```powershell
# Good
$path = Join-Path $PSScriptRoot "data"
$fullPath = "C:\Projects\msingi\msingi.ps1"

# Avoid
$path = "C:/Projects/msingi/data"
```

### Environment Variables & Expansion

### Variable Access
- **PowerShell**: Access via `$env:VAR`.
- **CMD**: Access via `%VAR%`.

### Expansion Rules
- **Home (~)**: Always expand `~` using `-replace '^~', $env:USERPROFILE`.

## Line Endings & Encoding

> CRLF rules and here-string invariants are defined in [`coding-standards.md`](coding-standards.md).
> This section covers Windows-specific detection only.

### Detection

```powershell
# Check if file has CRLF
$f = Get-Content file.txt -Raw
if ($f -notmatch "`r`n") {
    Write-Warning "File may have wrong line endings"
}
```

## Terminal Requirements

### Minimum Width

- TUI assumes 80+ character width
- `Write-TwoColumn` uses `[Console]::SetCursorPosition]`

### ANSI Support

- Requires Windows Terminal or modern conhost
- Legacy cmd.exe has limited color support

### Window Spawning

Msingi detects existing shell and spawns fresh window:

```powershell
# Spawns new Windows Terminal tab or conhost
if (-not $env:MSINGI_LAUNCHED) {
    Start-Process "wt.exe" -ArgumentList "pwsh.exe -File msingi.ps1"
}
```

## Shell Compatibility

### PowerShell 7

- Minimum version: 7.0
- Check: `$PSVersionTable.PSVersion.Major -ge 7`

### CMD

Limited support - use PowerShell for:
- JSON parsing
- Complex scripting
- File manipulation with Unicode

### Git Bash / WSL

- Use forward slashes in paths
- Some commands differ from native Linux

## Installation

### Profile Registration

```powershell
# Register in $PROFILE
$profilePath = $PROFILE.CurrentUserCurrentHost
$launcher = @"
function msingi {
    param(
        [switch]`$DryRun,
        [switch]`$Update,
        [switch]`$Check,
        [string]`$Path = ""
    )
    & 'C:\path\to\msingi.ps1' @PSBoundParameters
}
Set-Alias -Name bootstrap -Value msingi -Scope Global
"@
Add-Content $profilePath $launcher
```

### Execution Policy

If restricted:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## File System

### Reserved Characters

Avoid in filenames:
- `< > : " / \ | ? *`

### Long Paths

Windows MAX_PATH = 260 by default. Enable long paths:

```powershell
# Registry (run as admin)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Here-strings broken | Ensure CRLF line endings (see `coding-standards.md`) |
| Command not found | Use full path or `$env:PATH` |
| Permission denied | Run PowerShell as Administrator |
| Unicode issues | Use UTF-8 with BOM encoding |
| Path too long | Enable long paths or use `\\?\` prefix |
