---
description: Test and modify the Invoke-ProjectScan brownfield detection for existing codebases
---

# Workflow: Brownfield Scan

Guide for testing and modifying the `Invoke-ProjectScan` function that detects existing codebases.

## When to Use

- Modifying the brownfield detection algorithm in `Invoke-ProjectScan`
- Adding new file pattern recognition (e.g., new framework markers)
- Debugging false positives or missed detections in existing project scans

## Procedure

### 1. Understand the Scan Algorithm

`Invoke-ProjectScan` (line ~1759 in `msingi.ps1`) performs brownfield detection:
- Scans the target directory for known project markers
- Identifies existing frameworks, languages, and infrastructure
- Populates intake fields automatically from detected patterns
- Overlays the scaffold onto the existing directory structure

### 2. Identify the Change Scope

Determine which detection category is affected:

| Category | Markers | Examples |
|---|---|---|
| Language | File extensions, config files | `.py`, `go.mod`, `Cargo.toml` |
| Framework | Framework-specific files | `next.config.js`, `angular.json` |
| Infrastructure | CI/CD and deployment configs | `.github/workflows/`, `Dockerfile` |
| Data | Database configs | `prisma/schema.prisma`, `migrations/` |
| Testing | Test directories and configs | `jest.config.js`, `pytest.ini` |

### 3. Modify Detection in `msingi.ps1`

- Find `Invoke-ProjectScan` in `msingi.ps1` (~line 1759).
- Add or modify file pattern matching logic.
- Ensure detected values are stored in the state object for use by builders.

### 4. Mirror to `msingi.sh`

- Apply the equivalent detection logic in the Bash implementation.
- Use `test -f` and `find` commands instead of `Test-Path` and `Get-ChildItem`.

### 5. Test with Known Projects

Create temporary test directories with known markers and verify detection:

```powershell
# Create a test directory with Next.js markers
$testDir = Join-Path $env:TEMP "msingi-scan-test"
New-Item -ItemType Directory -Path $testDir -Force
New-Item -ItemType File -Path (Join-Path $testDir "next.config.js") -Force
New-Item -ItemType File -Path (Join-Path $testDir "package.json") -Force

# Run Msingi in brownfield mode pointing at the test directory
pwsh -File msingi.ps1 -DryRun -Path $testDir
```

### 6. Verify Parity

// turbo
```powershell
bash -n msingi.sh
```

### 7. Clean Up

```powershell
Remove-Item -Recurse -Force (Join-Path $env:TEMP "msingi-scan-test")
```

## Common Issues

| Issue | Fix |
|---|---|
| False positive detection | Tighten pattern matching with additional file checks |
| Missed detection | Add the missing file pattern to the scan function |
| PS7/Bash discrepancy | Use the `parity-engine` skill to align implementations |

---
*Part of Msingi Development Workflows*
