---
description: Track and validate Go rewrite progress against the PS7 reference implementation
---

# Workflow: Go Migration Check

Track Go rewrite progress and validate output parity with the PS7 reference.

## When to Use

- After porting a `Build-*` function to Go
- Before merging any Go rewrite PR
- When tracking overall migration progress

## Procedure

### 1. Generate PS7 Reference Output

Generate the reference scaffold from the PS7 implementation:

```powershell
pwsh -File msingi.ps1 -DryRun -Path .\test-reference-ps7
```

### 2. Generate Go Output

Run the Go binary with identical inputs:

```bash
cd nasdh
go run ./cmd/msingi --dry-run --path ../test-reference-go
```

### 3. Compare Outputs

```bash
diff -r test-reference-ps7 test-reference-go
```

All generated files must be byte-identical. The only acceptable differences are:
- Timestamp fields (use `--exclude='*.timestamp'` or post-process)
- Platform-specific metadata (e.g., "PS7" vs "Go" in headers)

### 4. Track Ported Functions

Maintain a checklist of ported builder functions:

| Function | PS7 Status | Go Status | Parity Verified |
|---|---|---|---|
| `Build-ContextMd` | Reference | ☐ | ☐ |
| `Build-TasksMd` | Reference | ☐ | ☐ |
| `Build-SecurityMd` | Reference | ☐ | ☐ |
| `Build-DomainMd` | Reference | ☐ | ☐ |
| `Build-WorkstreamsMd` | Reference | ☐ | ☐ |
| `Build-QualityMd` | Reference | ☐ | ☐ |
| `Build-EnvironmentsMd` | Reference | ☐ | ☐ |
| `Build-ObservabilityMd` | Reference | ☐ | ☐ |
| `Build-DiscoveryMd` | Reference | ☐ | ☐ |
| `Build-SessionMd` | Reference | ☐ | ☐ |
| `Build-NotesMd` | Reference | ☐ | ☐ |
| `Build-AgentConfig` | Reference | ☐ | ☐ |
| `Build-SkillSpec` | Reference | ☐ | ☐ |
| `Build-SkillGotchas` | Reference | ☐ | ☐ |
| `Build-BootstrapRecord` | Reference | ☐ | ☐ |

### 5. Run Go Tests

```bash
cd nasdh
go test ./...
```

### 6. Verify goreleaser Config

```bash
goreleaser check
```

### 7. Clean Up

```powershell
Remove-Item -Recurse -Force test-reference-ps7, test-reference-go
```

## Milestone Gates

| Gate | Criteria |
|---|---|
| **Alpha** | All builder functions ported, parity verified |
| **Beta** | TUI complete (all 7 screens), inference engine ported |
| **RC** | goreleaser config, cross-compilation, all tests passing |
| **v1.0.0** | Full feature parity, distribution channels active |

---
*Part of Msingi Development Workflows*
