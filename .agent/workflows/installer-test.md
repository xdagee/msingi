---
description: Validate install.ps1 in clean environments for execution policy, profile registration, and uninstall
---

# Workflow: Installer Test

Validate `install.ps1` across fresh environments and edge cases.

## When to Use

- After modifying `install.ps1`
- Before a release that changes installer behaviour
- When debugging installation failures on user machines

## Procedure

### 1. Validate Syntax

// turbo
```powershell
pwsh -Command "Get-Command -Syntax .\install.ps1"
```

### 2. Dry-Run Installation

Run the installer without writing anything to verify flow:

```powershell
pwsh -File install.ps1 -DryRun
```

Expected output:
- Environment validated
- Execution policy check passes (or shows "Would set...")
- Launcher registration shows "[DryRun]"
- Data validation passes for `agents.json` and `skills.json`

### 3. Version Consistency Check

Verify the installer version matches the main script:

```powershell
pwsh -Command "$installerVer = (Select-String 'function Get-MsingiVersion' install.ps1 -Context 0,1).Context.PostContext[0].Trim().Trim('\"'); $scriptVer = (Select-String '\$VERSION\s*=' msingi.ps1 | Select-Object -First 1).Line -replace '.*\"(.*)\".*', '$1'; if ($installerVer -ne $scriptVer) { Write-Host 'MISMATCH: install.ps1=$installerVer vs msingi.ps1=$scriptVer' } else { Write-Host 'OK: Both at v' + $scriptVer }"
```

### 4. Fresh Profile Test

Test with a temporary profile to avoid polluting the real one:

```powershell
$tempProfile = Join-Path $env:TEMP "msingi_test_profile.ps1"
# Note: This requires modifying the installer to accept a custom profile path
# For manual testing, inspect the profile content after install
```

### 5. Uninstall Test

```powershell
pwsh -File install.ps1 -Uninstall -DryRun
```

Verify:
- Profile entries would be removed
- No error on missing profile

### 6. Force Update Test

```powershell
pwsh -File install.ps1 -Force -DryRun
```

Verify:
- Existing launcher registration would be replaced (not duplicated)

### 7. Data File Validation

Ensure installer catches corrupt JSON:

```powershell
# The installer should validate agents.json and skills.json
# Check that it reports warnings for missing or corrupt files
```

## Common Issues

| Issue | Fix |
|---|---|
| Profile path doesn't exist | Installer should create the directory |
| Duplicate launcher entries | Use `-Force` to replace existing registration |
| Execution policy blocked | Installer falls back to Process-level Bypass |
| Version mismatch | Run `/version-bump` workflow first |

---
*Part of Msingi Development Workflows*
