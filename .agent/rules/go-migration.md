---
description: Constraints and conventions for the Go rewrite of Msingi (v1.0.0 roadmap)
---

# Rule: Go Migration Constraints

Governs the Go rewrite of Msingi, ensuring output parity during transition and idiomatic Go patterns.

## Scope

- **Source**: `nasdh/` directory (Go rewrite workspace)
- **Target**: Future `cmd/msingi/` and `internal/` packages
- **Subagents**: Go Migration Lead

## Metadata

- **Maintainer**: Go Migration Lead
- **Status**: Active Development
- **Target Version**: v1.0.0

## Context

The Go rewrite replaces both `msingi.ps1` and `msingi.sh` with a single cross-platform binary. During the transition period, the PS7 version remains the source of truth for generated output.

## Output Parity

- **Byte-Identical**: Mandatory: Go builders must produce byte-identical output to PS7 `Build-*Md` functions.
- **Source of Truth**: PS7 is the reference implementation until Go reaches feature parity.
- **Verification**: Every ported builder must be tested against PS7 output using `diff`.
- **Exceptions**: Only timestamps and the platform tag ("PS7" vs "Go") may differ.

## Go Conventions

### Project Structure
- **Mandatory**: Use `cmd/msingi/main.go` as the single entry point.
- **Mandatory**: All internal packages under `internal/` — no exported API.
- **Pattern**: One package per concern: `tui`, `builder`, `inference`, `data`, `config`.

### Dependencies
- **TUI**: Charm's Bubble Tea (`github.com/charmbracelet/bubbletea`).
- **Styling**: Charm's Lipgloss (`github.com/charmbracelet/lipgloss`).
- **CLI Flags**: Cobra (`github.com/spf13/cobra`) or standard `flag` package.
- **Requirement**: Ensure pure Go dependencies only — the binary must cross-compile cleanly.
- **Requirement**: Preserve offline-first design — ensure zero network dependencies at runtime.

### Data Embedding
- **Mandatory**: Use `go:embed` for `agents.json` and `skills.json`.
- **Mandatory**: Deserialize into typed structs — no `map[string]interface{}`.
- **Pattern**: Validate embedded data at init time, fail fast on schema violations.

### Error Handling
- **Mandatory**: Use explicit error returns — no `panic()` except for truly unrecoverable states.
- **Pattern**: Wrap errors with context using `fmt.Errorf("operation: %w", err)`.
- **Requirement**: Log or propagate every error — ensure errors are visible and traceable.

### Testing
- **Mandatory**: Unit tests for every builder function (`builder_test.go`).
- **Mandatory**: Integration tests comparing Go output to PS7 reference output.
- **Pattern**: Use `testdata/` directories for golden file tests.

## TUI Constraints

### Bubble Tea Architecture
- **Model**: Single `Model` struct containing all application state.
- **Messages**: Typed messages — no raw strings for inter-component communication.
- **Views**: One view function per screen (7 screens matching PS7 flow).
- **Responsive**: Handle `tea.WindowSizeMsg` for terminal resize events.

### Lipgloss Styling
- **Brand Palette**: Teal `#00D2C8`, gold accents, slate grays — match PS7 exactly.
- **Pattern**: Package-level style constants — no inline style definitions.
- **Border**: Use Lipgloss border types, not manual Unicode box-drawing.

## Distribution

### goreleaser
- **Mandatory**: Cross-compile for Windows (amd64), macOS (amd64, arm64), Linux (amd64, arm64).
- **Mandatory**: Generate checksums and changelog from conventional commits.
- **Pattern**: Archive format — `.tar.gz` for Unix, `.zip` for Windows.

### Package Managers
- **Windows**: Scoop manifest in a tap repository.
- **macOS**: Homebrew formula in a tap repository.
- **Linux**: Direct binary download from GitHub Releases.

## Migration Tracking

- **Mandatory**: Maintain a ported function checklist in the Go migration workflow.
- **Pattern**: Port builders first (pure functions), then TUI (stateful), then inference (complex).
- **Gate**: Do not release Go v1.0.0 until all 50 tests pass against Go output.
