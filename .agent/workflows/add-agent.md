---
description: Register a new agent in agents.json and wire it into the scaffold generator
---

# Workflow: Add Agent

Follow these steps to register a new AI coding agent in Msingi's agent registry.

## When to Use

- Adding support for a new AI coding agent (e.g., a new CLI tool or IDE extension)
- Updating an existing agent's metadata (docs URL, capabilities, roles)

## Procedure

### 1. Prepare Agent Metadata

Gather the following required fields:

| Field | Format | Example |
|---|---|---|
| `id` | kebab-case, ≤40 chars | `cursor-ai` |
| `name` | Human-readable display name | `Cursor AI` |
| `file` | Config filename (`.md` or `.json`) | `CURSOR.md` |
| `scratchpad` | Folder name under `scratchpads/` | `cursor` |
| `category` | `vendor`, `vendor-oss`, `oss`, `framework-oss` | `vendor` |
| `repo` | GitHub URL (empty string if closed-source) | `""` |
| `description` | One-line description | `AI-native code editor` |
| `docsUrl` | Documentation URL | `https://docs.cursor.com` |
| `capabilityToAct` | Array of capabilities | `["file-system", "terminal"]` |
| `selfDirection` | `high`, `medium`, `low` | `high` |
| `roles` | Array of `coordinator`, `planner`, `executor` | `["executor"]` |

### 2. Edit `agents.json`

Add the new agent object to the `agents` array. Ensure no duplicate `id` values.

### 3. Validate JSON

// turbo
```powershell
pwsh -Command "$data = Get-Content agents.json | ConvertFrom-Json; if ($data.schema_version -ne '1.0' -or -not $data.agents) { throw 'Invalid schema' }; Write-Host 'OK: ' + $data.agents.Count + ' agents'"
```

### 4. Check for Duplicate IDs

```powershell
pwsh -Command "$a = (Get-Content agents.json | ConvertFrom-Json).agents; $ids = $a | ForEach-Object { $_.id }; $dupes = $ids | Group-Object | Where-Object Count -gt 1; if ($dupes) { Write-Host 'DUPLICATES:' $dupes.Name } else { Write-Host 'OK: No duplicates' }"
```

### 5. Update `Build-AgentConfig` in `msingi.ps1`

- If the new agent uses a **JSON config format** (like Opencode's `opencode.json`), add a special-case handler in the `Build-AgentConfig` emit loop.
- If the agent uses a standard **Markdown config** (`.md`), no changes to the emit loop are needed.

### 6. Mirror to `msingi.sh`

- Apply the same `Build-AgentConfig` changes to the Bash implementation.
- Use the `audit-parity` workflow to verify.

### 7. Run Test Suite

// turbo
```powershell
python3 tests/test_suite.py
```

### 8. Commit

```bash
git add agents.json msingi.ps1 msingi.sh
git commit -m "feat(agent): add <id> to agent registry"
```

## Common Issues

| Issue | Fix |
|---|---|
| Duplicate ID | Rename one of the entries |
| Missing required field | Add all fields from the table above |
| JSON config not generating | Add special case in `Build-AgentConfig` |
| Parity failure | Mirror changes to `msingi.sh` |

---
*Part of Msingi Development Workflows*
