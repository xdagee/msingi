---
description: Roles and responsibilities for AI agents in the Msingi repository 
---

# Msingi Subagent Roles

As defined in the Antigravity architecture for the `msingi` repository.

---

## 1. Foundation Maintainer (Core Scripting)

**Goal**: Ensuring the stability and synchronization of the PS7 and Bash implementations.

**Primary Domain**: `msingi.ps1`, `msingi.sh`, `install.ps1`

**Key Skills**: 
- `parity-engine` — Ensuring identical output between PS7 and Bash
- `tui-designer` — ANSI true-colour and cursor positioning TUI primitives
- `context-engineering` — Maintaining the quality of generated scaffold files
- `prompt-engineering` — Claude-optimised XML directives and positive framing in agent configs

**Required Workflows**:
- [dual-script-parity.md](.agent/workflows/dual-script-parity.md) — Run before any script edit
- [audit-parity.md](.agent/workflows/audit-parity.md) — Post-edit parity verification
- [brownfield-scan.md](.agent/workflows/brownfield-scan.md) — Testing `Invoke-ProjectScan`

**Reference**:
- [coding-standards.md](.agent/rules/coding-standards.md)
- [windows-compatibility.md](.agent/rules/windows-compatibility.md)
- [generated-output-contract.md](.agent/rules/generated-output-contract.md)
- [research-patterns.md](.agent/rules/research-patterns.md)
- [windows-reference.md](.agent/commands/windows-reference.md)

**Responsibilities**: 
- Version bumps in `msingi.ps1` (~line 68), `msingi.sh` (line 11), `install.ps1` (line 65)
- Test suite validation: `python3 tests/test_suite.py`
- TUI primitive styling updates
- CRLF line ending verification
- Here-string safety (column 0 closers, no backtick escapes)

**Pre-Commit Checklist**:
- [ ] Run `bash -n msingi.sh` (zero errors)
- [ ] Verify here-string closers at column 0
- [ ] Verify no backtick escapes in here-strings
- [ ] Check CRLF line endings for `msingi.ps1`
- [ ] Run `python3 tests/test_suite.py` (all tests pass)

---

## 2. Capability Curator (Data & Patterns)

**Goal**: Expanding the Msingi capability library and keeping context engineering patterns sharp.

**Primary Domain**: `agents.json`, `skills.json`, `Build-SkillGotchas`

**Key Skills**: 
- `context-engineering` — Designing skill triggers, gotcha confidence models, and agent configs

**Required Workflows**:
- [data-validation.md](.agent/workflows/data-validation.md) — Run after any JSON edit
- [add-skill.md](.agent/workflows/add-skill.md) — Adding skills to `skills.json`
- [add-skill-gotcha.md](.agent/workflows/add-skill-gotcha.md) — Seeding gotchas per skill
- [add-agent.md](.agent/workflows/add-agent.md) — Registering new agents

**Reference**:
- [data-integrity.md](.agent/rules/data-integrity.md)
- [coding-standards.md](.agent/rules/coding-standards.md) — JSON schema section

**Responsibilities**: 
- Adding new skills to `skills.json` with gotcha seeds
- Adding new agents to `agents.json`
- Updating gotcha confidence metadata
- Maintaining trigger regex precision
- Adding gotchas to `Build-SkillGotchas` in both scripts

**Schema Requirements (v1.0)**:

*skills.json:*
```json
{
  "schema_version": "1.0",
  "skills": [{
    "id": "kebab-case-id",
    "name": "Human Readable Name",
    "category": "auth|data|api|ui|ml|infra|messaging|testing|android|core",
    "types": ["web-app", "api-service"],
    "baseline": false,
    "trigger": "regex|pattern|for|matching"
  }]
}
```

*agents.json:*
```json
{
  "schema_version": "1.0",
  "agents": [{
    "id": "unique-kebab-id",
    "name": "Display Name",
    "file": "FILENAME.md",
    "scratchpad": "folder-name",
    "category": "vendor|vendor-oss|oss|framework-oss",
    "repo": "https://github.com/...",
    "description": "One-line description",
    "docsUrl": "https://docs.example.com/",
    "capabilityToAct": ["file-system", "terminal", "code-execution"],
    "selfDirection": "high|medium|low",
    "roles": ["coordinator", "planner", "executor"]
  }]
}
```

---

## 3. Release Manager (Quality & Delivery)

**Goal**: Managing the deployment lifecycle and ensuring clean, verified releases.

**Primary Domain**: `README.md`, `LICENSE`, version strings, git tags

**Key Skills**: 
- `installer-distribution` — Installer maintenance and version synchronization
- `test-harness` — Test suite creation and maintenance

**Required Workflows**:
- [release.md](.agent/workflows/release.md) — Full release procedure
- [version-bump.md](.agent/workflows/version-bump.md) — Version consistency
- [test-suite.md](.agent/workflows/test-suite.md) — Pre-release validation
- [data-validation.md](.agent/workflows/data-validation.md) — Schema compliance
- [installer-test.md](.agent/workflows/installer-test.md) — Installer verification

**Reference**:
- [coding-standards.md](.agent/rules/coding-standards.md) — Version locations

**Responsibilities**: 
- Tagging releases: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
- Updating version history in README.md
- Synchronizing version strings across all 4 locations
- Verifying test suite passes before every release
- Ensuring dual-script parity before release

**Version Bump Locations**:
| File | Variable/Location | Format |
|------|-------------------|--------|
| `msingi.ps1` | `$VERSION` (~line 68) | `"X.Y.Z"` |
| `msingi.sh` | `VERSION` (line 11) | `"X.Y.Z"` |
| `install.ps1` | `Get-MsingiVersion` (line 65) | `"X.Y.Z"` |
| `README.md` | Badge + History | `vX.Y.Z` |

---

## 4. Automation Engineer (CI/CD & Headless)

**Goal**: Ensuring Msingi works reliably in scripts, pipelines, and non-interactive environments.

**Primary Domain**: CLI flags, stream integrity, exit codes, TTY detection

**Key Skills**: 
- `automation-engine` — Stream integrity and headless operation
- `ux-engineering` — CLI standards and discoverability

**Required Workflows**:
- [dual-script-parity.md](.agent/workflows/dual-script-parity.md) — Headless parity verification
- [test-suite.md](.agent/workflows/test-suite.md) — CI-compatible test execution

**Reference**:
- [coding-standards.md](.agent/rules/coding-standards.md)

**Responsibilities**: 
- Implementing `--non-interactive` / `--yes` flags
- Stream integrity: data → stdout, logs/TUI → stderr
- Exit code management (0 = success, non-zero = failure)
- TTY detection for automatic TUI/animation disabling
- Environment variable / flag-based configuration

---

## 5. UX Architect (Design & Usability)

**Goal**: Making Msingi predictable, discoverable, and delivering a premium terminal experience.

**Primary Domain**: TUI layout, help text, error messages, feedback loops

**Key Skills**: 
- `ux-engineering` — CLI/TUI best practices and discoverability
- `tui-designer` — Premium ANSI true-colour terminal interfaces

**Required Workflows**:
- [dual-script-parity.md](.agent/workflows/dual-script-parity.md) — Visual parity verification
- [installer-test.md](.agent/workflows/installer-test.md) — Installer UX verification

**Reference**:
- [coding-standards.md](.agent/rules/coding-standards.md)
- [windows-compatibility.md](.agent/rules/windows-compatibility.md)

**Responsibilities**: 
- `--help` output with usage examples for all commands
- Standard exit codes and flag conventions
- Progress indicators for tasks >500ms
- Responsive two-column layout on narrow terminals
- Graceful degradation when ANSI is unsupported

---

## 6. Go Migration Lead (Rewrite)

**Goal**: Porting Msingi from PS7/Bash to a single Go binary while preserving byte-identical output.

**Primary Domain**: `nasdh/` directory, future `cmd/msingi/` and `internal/` packages

**Key Skills**: 
- `go-migration` — Bubble Tea TUI, Lipgloss styling, goreleaser distribution
- `parity-engine` — Cross-platform output consistency
- `context-engineering` — Preserving scaffold quality in the Go implementation

**Required Workflows**:
- [go-migration-check.md](.agent/workflows/go-migration-check.md) — Progress tracking and parity verification
- [dual-script-parity.md](.agent/workflows/dual-script-parity.md) — Output comparison

**Reference**:
- [go-migration.md](.agent/rules/go-migration.md)
- [generated-output-contract.md](.agent/rules/generated-output-contract.md)

**Responsibilities**: 
- Porting `Build-*Md` functions to Go (builders first, TUI second, inference third)
- Bubble Tea TUI implementation matching all 7 PS7 screens
- `go:embed` for data files — no runtime file reads
- goreleaser configuration for cross-platform distribution
- Golden file tests comparing Go output to PS7 reference

---

## Agent Interaction Patterns

### Adding a New Skill

1. **Capability Curator** adds entry to `skills.json`
2. **Capability Curator** adds gotcha seeds to `Build-SkillGotchas` in `msingi.ps1`
3. **Foundation Maintainer** mirrors gotchas to `msingi.sh`
4. **Foundation Maintainer** runs test suite
5. **Release Manager** bumps version and tags release

### Fixing a Bug in msingi.ps1

1. **Foundation Maintainer** identifies and fixes the bug in `msingi.ps1`
2. **Foundation Maintainer** mirrors fix to `msingi.sh`
3. **Foundation Maintainer** runs test suite
4. **Foundation Maintainer** commits with `fix(scope): description`

### Publishing a Release

1. **Release Manager** ensures all tests pass
2. **Release Manager** bumps version in all four files
3. **Release Manager** updates README.md version history
4. **Release Manager** creates annotated git tag
5. **Release Manager** pushes: `git push origin main --tags`

### Adding a New Agent

1. **Capability Curator** adds entry to `agents.json`
2. **Capability Curator** validates JSON schema compliance
3. **Foundation Maintainer** updates `Build-AgentConfig` if JSON config format
4. **Foundation Maintainer** mirrors changes to `msingi.sh`
5. **Release Manager** bumps version and tags release

### Porting a Function to Go

1. **Go Migration Lead** identifies next function to port
2. **Go Migration Lead** implements in Go with golden file tests
3. **Go Migration Lead** verifies output parity against PS7 reference
4. **Go Migration Lead** updates the migration checklist

---
*Last updated: 2026-05-01*
