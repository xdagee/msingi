---
description: Synchronize version strings across scripts, documentation, and data registries
---

# Workflow: Version Bump

Maintain version consistency across all Msingi core files and data registries.

## Procedures

### 1. Version Scoping
Review semantic versioning requirements:
- **Major**: Breaking changes / Core architecture shift.
- **Minor**: New features / Schema updates (e.g., 1.0 to 1.1).
- **Patch**: Bug fixes / Logic stabilization.

### 2. File Updates
Update the version string in the following locations:

| File | Variable/Location | Format |
|------|-------------------|--------|
| `msingi.ps1` | `$VERSION` (~line 63) | `"X.Y.Z"` |
| `msingi.sh` | `VERSION` (line 17) | `"X.Y.Z"` |
| `README.md` | Badge + History | `vX.Y.Z` |
| `agents.json` | `schema_version` | `"1.0"` (if applicable) |
| `skills.json` | `schema_version` | `"1.0"` (if applicable) |

### 3. Scripted Updates

**PowerShell One-Liner:**
```powershell
$new="3.8.2"; (gc msingi.ps1) -replace '\$VERSION = ".*"', "`$VERSION = `"$new`"" | sc msingi.ps1
```

**Bash One-Liner:**
```bash
sed -i 's/VERSION="[0-9.]*"/VERSION="3.8.2"/' msingi.sh
```

### 4. Verification
- **Diff**: Run `git diff --stat` to ensure all target files are modified.
- **Suite**: Execute `python3 tests/test_suite.py` to confirm no regressions.
- **Data Validation**: Run `/data-validation` if schema versioning was touched.

### 5. Rollback
If errors occur: `git checkout HEAD -- msingi.ps1 msingi.sh README.md`.
