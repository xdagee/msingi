# Windows Reference Commands

This document maps all critical Msingi development commands to PowerShell 7 and Windows CMD equivalents.

## Directory Commands

| Operation | PowerShell 7 | CMD | Notes |
|-----------|-------------|-----|-------|
| List files | `Get-ChildItem` | `dir` | |
| List recursive | `Get-ChildItem -Recurse` | `dir /s` | |
| Current directory | `Get-Location` | `cd` | |
| Create directory | `New-Item -ItemType Directory -Path foo` | `mkdir foo` | |
| Remove directory | `Remove-Item -Recurse -Force foo` | `rmdir /s /q foo` | |

## File Operations

| Operation | PowerShell 7 | CMD | Notes |
|-----------|-------------|-----|-------|
| Read file | `Get-Content file.txt` | `type file.txt` | |
| Write file | `Set-Content file.txt "content"` | `echo content > file.txt` | |
| Append file | `Add-Content file.txt "content"` | `echo content >> file.txt` | |
| Copy file | `Copy-Item src dst` | `copy src dst` | |
| Move file | `Move-Item src dst` | `move src dst` | |
| Delete file | `Remove-Item file.txt` | `del file.txt` | |
| File exists | `Test-Path file.txt` | `if exist file.txt` | |

## Git Commands

| Operation | PowerShell 7 | CMD | Notes |
|-----------|-------------|-----|-------|
| Status | `git status` | `git status` | Same |
| Diff staged | `git diff --cached` | `git diff --cached` | Same |
| Diff | `git diff` | `git diff` | Same |
| Add all | `git add .` | `git add .` | Same |
| Commit | `git commit -m "msg"` | `git commit -m "msg"` | Same |
| Log | `git log --oneline -10` | `git log --oneline -10` | Same |

## Test Commands

| Operation | PowerShell 7 | CMD | Notes |
|-----------|-------------|-----|-------|
| Run test suite | `python3 tests/test_suite.py` | `python tests\test_suite.py` | Python must be in PATH |
| PS7 unit tests | `pwsh -File tests/install.tests.ps1` | N/A | Requires PowerShell 7 |
| Bash syntax | `bash -n msingi.sh` | `bash -n msingi.sh` | Requires Bash (WSL/Git Bash) |
| JSON validate | `pwsh -Command "Get-Content agents.json \| ConvertFrom-Json"` | N/A | Requires PowerShell |

## JSON Validation

| Operation | PowerShell 7 | CMD | Notes |
|-----------|-------------|-----|-------|
| Validate agents.json | `pwsh -Command "Get-Content agents.json \| ConvertFrom-Json \| Out-Null"` | N/A | |
| Validate skills.json | `pwsh -Command "Get-Content skills.json \| ConvertFrom-Json \| Out-Null"` | N/A | |
| Pretty print | `pwsh -Command "Get-Content file.json \| ConvertFrom-Json \| ConvertTo-Json"` | N/A | |

## Line Ending Fix

| Operation | PowerShell 7 | CMD | Notes |
|-----------|-------------|-----|-------|
| Fix CRLF | `python3 -c "open('f','wb').write(open('f','rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))"` | Same | Run from repo root |

## Path Formats

| Context | Format | Example |
|---------|--------|---------|
| PowerShell | Backslash `\` | `C:\path\to\file` |
| PowerShell env | `$env:VAR` | `$env:USERPROFILE` |
| CMD | Backslash `\` | `C:\path\to\file` |
| CMD env | `%VAR%` | `%USERPROFILE%` |
| Git Bash | Forward slash `/` | `/c/path/to/file` |
| WSL | Forward slash `/` | `/mnt/c/path/to/file` |

## Environment Variables

| Operation | PowerShell 7 | CMD | Notes |
|-----------|-------------|-----|-------|
| List all | `Get-ChildItem Env:` | `set` | |
| Get value | `$env:VAR` | `%VAR%` | |
| Set value | `$env:VAR = "value"` | `set VAR=value` | Temporary |
| Set persistent | `[System.Environment]::SetEnvironmentVariable("VAR", "value", "User")` | `setx VAR value` | Requires restart |

## Process Commands

| Operation | PowerShell 7 | CMD | Notes |
|-----------|-------------|-----|-------|
| List processes | `Get-Process` | `tasklist` | |
| Kill process | `Stop-Process -Name name` | `taskkill /IM name.exe` | |
| Start process | `Start-Process app` | `start app` | |

## Network Commands

| Operation | PowerShell 7 | CMD | Notes |
|-----------|-------------|-----|-------|
| Test connection | `Test-NetConnection host -Port 443` | `ping host` | |
| Get IP | `(Invoke-WebRequest -Uri ifconfig.me).Content` | `ipconfig` | |

## PowerShell-Specific

| Operation | Command | Notes |
|-----------|---------|-------|
| Run script | `.\msingi.ps1` | Requires `-ExecutionPolicy Bypass` if restricted |
| Run with args | `.\msingi.ps1 -DryRun -Path C:\project` | |
| Get PS version | `$PSVersionTable.PSVersion` | |
| Install module | `Install-Module -Name ModuleName` | Requires admin |

## Common Aliases

| Alias | Full Command |
|-------|--------------|
| `ls` | `Get-ChildItem` |
| `cat` | `Get-Content` |
| `rm` | `Remove-Item` |
| `cp` | `Copy-Item` |
| `mv` | `Move-Item` |
| `cd` | `Set-Location` |
| `pwd` | `Get-Location` |
| `echo` | `Write-Output` |
| `grep` | `Select-String` |

---
*Part of Msingi Agent Operations*
