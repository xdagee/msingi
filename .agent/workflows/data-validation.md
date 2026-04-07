---
description: Validate agents.json and skills.json schema compliance
---

# Workflow: Data Validation

This workflow ensures `agents.json` and `skills.json` maintain schema compliance and data integrity.

## When to Use

- Before any commit that modifies `agents.json`
- Before any commit that modifies `skills.json`
- After adding new skills or agents

## Procedure

### 1. Validate JSON Syntax

**PowerShell 7:**
```powershell
pwsh -Command "$data = Get-Content agents.json | ConvertFrom-Json; if ($data.schema_version -ne '1.0' -or -not $data.agents) { throw 'Invalid schema' }"
pwsh -Command "$data = Get-Content skills.json | ConvertFrom-Json; if ($data.schema_version -ne '1.0' -or -not $data.skills) { throw 'Invalid schema' }"
```

**Python:**
```bash
python3 -c "import json; d=json.load(open('agents.json')); assert d['schema_version'] == '1.0' and 'agents' in d"
python3 -c "import json; d=json.load(open('skills.json')); assert d['schema_version'] == '1.0' and 'skills' in d"
```

### 2. Validate Schema

#### agents.json Required Fields
- `schema_version` — must be "1.0"
- `agents` — array of agent objects:
    - `id` — unique kebab-case identifier
    - `name` — human-readable display name
    - `file` — config file name (e.g., `CLAUDE.md`, `opencode.json`)
    - `scratchpad` — folder name under `scratchpads/`
    - `category` — one of: `vendor`, `vendor-oss`, `oss`, `framework-oss`
    - `repo` — GitHub URL (empty string if closed-source)
    - `description` — one-line description
    - `docsUrl` — documentation URL

#### skills.json Required Fields
- `schema_version` — must be "1.0"
- `skills` — array of skill objects:
    - `id` — unique kebab-case identifier (≤40 chars)
    - `name` — human-readable display name
    - `category` — one of: `auth`, `data`, `api`, `ui`, `ml`, `infra`, `messaging`, `testing`, `android`
    - `types` — array from: `web-app`, `api-service`, `fullstack`, `ml-ai`, `cli-tool`, `android`
    - `baseline` — boolean (`true` = always included for matching types)
    - `trigger` — case-insensitive regex

### 3. Check for Duplicate IDs

```powershell
pwsh -Command "$a = (Get-Content agents.json | ConvertFrom-Json).agents; $ids = $a | ForEach-Object { $_.id }; if (($ids | Group-Object | Where-Object Count -gt 1)) { Write-Host 'DUPLICATES FOUND' } else { Write-Host 'OK' }"
```

### 4. Validate Trigger Regex

Test that triggers are valid regex:

```powershell
pwsh -Command "$skills = (Get-Content skills.json | ConvertFrom-Json).skills; foreach ($s in $skills) { try { [regex]::new($s.trigger) } catch { Write-Host \"Invalid regex in \$(\$s.id): \$(\$_.Exception.Message)\" } }"
```

## Validation Script

Run all validations at once:

```bash
python3 tests/test_suite.py
```

## Common Issues

| Issue | Fix |
|-------|-----|
| Duplicate ID | Rename one of the entries |
| Invalid regex | Fix trigger pattern syntax |
| Missing field | Add required field |
| Wrong category | Use valid category from list |
| Types array empty | Add at least one valid type |

## Rollback

If validation fails:
1. Do NOT commit
2. Fix the validation errors
3. Re-run validation
4. Commit only after all pass

---
*Part of Msingi Development Workflows*
