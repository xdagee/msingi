---
name: go-migration
description: Use when working on the Go rewrite of Msingi, ensuring output parity with PS7/Bash and proper Bubble Tea TUI implementation.
---

# Go Migration Skill

Guide the Go rewrite of Msingi (v1.0.0 roadmap), ensuring output parity and idiomatic Go patterns.

## Role

You are the **Go Migration Lead**. Your goal is to port Msingi from PS7/Bash to a single Go binary while preserving byte-identical scaffold output.

## Context

The Go rewrite is tracked in the `nasdh/` directory (which currently contains an example scaffold output for reference). The target is a single binary with zero runtime dependencies, distributed via goreleaser. The TUI uses Charm's Bubble Tea + Lipgloss stack.

## Instructions

1. **Output Parity Contract**:
   - Mandatory: Every `Build-*Md` function ported to Go must produce byte-identical output to the PS7 reference implementation.
   - Verification: Use `diff` against PS7 dry-run output for every ported builder.
   - Transition: During the migration period, the PS7 version remains the source of truth.

2. **TUI Architecture (Bubble Tea)**:
   - Pattern: Use the Elm architecture — Model, Update, View.
   - Model: Central state struct containing all intake answers, navigation position, and UI state.
   - Messages: Typed messages for key events, tick events, and async data loading.
   - Views: Map each PS7 screen (7 screens) to a Bubble Tea view function.

3. **Styling (Lipgloss)**:
   - Mandatory: Replicate the teal brand palette (`#00D2C8`), gold accents, and slate grays.
   - Pattern: Define all styles as package-level Lipgloss constants.
   - Box drawing: Use Lipgloss border styles, not manual Unicode characters.
   - Responsive: Handle terminal resize events via `tea.WindowSizeMsg`.

4. **Data Loading**:
   - Mandatory: Embed `agents.json` and `skills.json` using `go:embed`.
   - Pattern: Deserialize into typed structs at startup — no runtime file reads needed.
   - Validation: Schema validation at build time via struct tags or init functions.

5. **Inference Engine**:
   - Port: `Invoke-SkillInference` two-pass algorithm (type-scope → trigger-match).
   - Pattern: Compile all trigger regexes once at startup using `regexp.MustCompile`.
   - Testing: Unit tests for each skill category with known inputs and expected matches.

6. **Distribution (goreleaser)**:
   - Mandatory: Cross-compile for Windows (amd64), macOS (amd64, arm64), Linux (amd64, arm64).
   - Pattern: Use `.goreleaser.yaml` with checksum, changelog, and archive configurations.
   - Install: Support `brew install`, `scoop install`, and direct binary download.

7. **Project Structure**:
   - `cmd/msingi/main.go` — entry point.
   - `internal/tui/` — Bubble Tea models and views.
   - `internal/builder/` — scaffold file generators (one per Build-* function).
   - `internal/inference/` — skill inference engine.
   - `internal/data/` — embedded JSON and typed structs.
   - `internal/config/` — CLI flags and configuration.
