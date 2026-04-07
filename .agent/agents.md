---
description: Roles and responsibilities for AI agents in the Msingi repository 
---

# Msingi Subagent Roles

As defined in the Antigravity architecture for the `msingi` repository.

## 1. Msingi Maintainer (Core Scripting)

**Goal**: Ensuring the stability and synchronization of the PS7 and Bash implementations.

**Primary Domain**: `msingi.ps1`, `msingi.sh`, `Install.ps1`, `tests/`

**Key Skills**: 
- `ps7-tui-engine` — PowerShell 7 TUI primitives and window management
- `dual-script-parity` — Ensuring identical output between PS7 and Bash
- `windows-compatibility` — CRLF, here-strings, BOM encoding

**Required Workflows**:
- [dual-script-parity.md](.agent/workflows/dual-script-parity.md) — Run before any script edit
- [version-bump.md](.agent/workflows/version-bump.md) — Version consistency across files

**Reference**:
- [coding-standards.md](.agent/rules/coding-standards.md)
- [windows-compatibility.md](.agent/rules/windows-compatibility.md)
- [windows-reference.md](.agent/commands/windows-reference.md)

**Responsibilities**: 
- Version bumps in `msingi.ps1` (line ~63), `msingi.sh` (line 17)
- Test suite validation: `python3 tests/test_suite.py`
- TUI primitive styling updates
- CRLF line ending verification

**Pre-Commit Checklist**:
- [ ] Run `python3 tests/test_suite.py` (all 27 tests pass)
- [ ] Verify here-string closers at column 0
- [ ] Verify no backtick escapes in here-strings
- [ ] Check Bash syntax: `bash -n msingi.sh`

---

## 2. Capability Archivist (Data & Patterns)

**Goal**: Expanding the Msingi capability library and keeping context engineering patterns sharp.

**Primary Domain**: `agents.json`, `skills.json`

**Key Skills**: 
- `context-engineering` — Designing skill triggers and agent configs
- `trigger-regex` — Writing precise case-insensitive regex patterns
- `json-schema-validation` — Ensuring valid JSON with required fields

**Required Workflows**:
- [data-validation.md](.agent/workflows/data-validation.md) — Run after any JSON edit

**Reference**:
- [data-integrity.md](.agent/rules/data-integrity.md)
- [coding-standards.md](.agent/rules/coding-standards.md) — JSON schema section

**Responsibilities**: 
- Adding new skills to `skills.json` with gotcha seeds
- Adding new agents to `agents.json`
- Updating gotcha confidence metadata
- Documenting new "context budget" rules
- Adding gotchas to `Build-SkillGotchas` in both scripts

**Schema Requirements (v1.0)**:

*skills.json:*
```json
{
  "schema_version": "1.0",
  "skills": [
    {
      "id": "kebab-case-id",
      "name": "Human Readable Name",
      "category": "auth|data|api|ui|ml|infra|messaging|testing|android",
      "types": ["web-app", "api-service"],
      "baseline": false,
      "trigger": "regex|pattern|for|matching"
    }
  ]
}
```

*agents.json:*
```json
{
  "schema_version": "1.0",
  "agents": [
    {
      "id": "unique-kebab-id",
      "name": "Display Name",
      "file": "FILENAME.md",
      "scratchpad": "folder-name",
      "category": "vendor|vendor-oss|oss|framework-oss",
      "repo": "https://github.com/...",
      "description": "One-line description",
      "docsUrl": "https://docs.example.com/"
    }
  ]
}
```

---

## 3. Release Manager (Quality & Delivery)

**Goal**: Managing the deployment lifecycle and ensuring clear communication of changes.

**Primary Domain**: `README.md`, `LICENSE`, Tags/Versions

**Key Skills**: 
- `version-bump` — Semantic versioning and changelog management
- `release-verification` — Ensuring test suite passes before release
- `documentation` — Keeping README and release notes current

**Required Workflows**:
- [release.md](.agent/workflows/release.md) — Full release procedure
- [test-suite.md](.agent/workflows/test-suite.md) — Pre-release validation
- [version-bump.md](.agent/workflows/version-bump.md) — Version consistency

**Reference**:
- [coding-standards.md](.agent/rules/coding-standards.md) — Version locations

**Responsibilities**: 
- Tagging releases: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
- Updating version history in README.md
- Verifying binary stability
- Announcing releases

**Version Bump Locations**:
| File | Variable/Location | Format |
|------|-------------------|--------|
| `msingi.ps1` | `$VERSION` (~line 63) | `"X.Y.Z"` |
| `msingi.sh` | `VERSION` (line 17) | `"X.Y.Z"` |
| `README.md` | Badge + History | `vX.Y.Z` |
| `agents.json` | `schema_version` | `"1.0"` |
| `skills.json` | `schema_version` | `"1.0"` |

---

## Agent Interaction Patterns

### Adding a New Skill

1. **Capability Archivist** adds entry to `skills.json`
2. **Capability Archivist** adds gotcha seeds to `Build-SkillGotchas` in `msingi.ps1`
3. **Msingi Maintainer** mirrors gotchas to `msingi.sh`
4. **Msingi Maintainer** runs test suite
5. **Release Manager** bumps version and tags release

### Fixing a Bug in msingi.ps1

1. **Msingi Maintainer** identifies the bug
2. **Msingi Maintainer** fixes the issue in `msingi.ps1`
3. **Msingi Maintainer** mirrors fix to `msingi.sh`
4. **Msingi Maintainer** runs test suite
5. **Msingi Maintainer** commits with appropriate message

### Publishing a Release

1. **Release Manager** ensures all tests pass
2. **Release Manager** bumps version in all three files
3. **Release Manager** creates git tag
4. **Release Manager** pushes to remote: `git push origin main --tags`
5. **Release Manager** updates release notes

---
*Last updated: 2026-03-30*
