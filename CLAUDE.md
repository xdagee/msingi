# CLAUDE.md

> **Pointer file.** All project documentation lives in [`AGENTS.md`](AGENTS.md) — read that instead.
> This file exists only because Claude Code auto-loads `CLAUDE.md` at the repo root.

## Session Start — Read in This Order

1. `scratchpads/claude-code/SESSION.md` — where did the last session leave off?
2. `TASKS.md` — what is the current work?
3. `AGENTS.md` — canonical project documentation (architecture, constraints, patterns, contributor guide)
4. `CONTEXT.md` — full architecture (skim unless directly relevant)

## Claude-Specific Reference Docs

- Claude Code: https://code.claude.com/docs/en/overview
- Bubble Tea: https://github.com/charmbracelet/bubbletea
- Lipgloss: https://github.com/charmbracelet/lipgloss
- goreleaser: https://goreleaser.com

## Additional Documentation

The `.agent/` directory contains detailed workflows and rules for Msingi development:
- `.agent/workflows/` — detailed procedures for common tasks (dual-script parity, version bump, test suite, release)
- `.agent/rules/` — platform-specific constraints and coding standards (Windows compatibility, data integrity)
- `.agent/agents/` — agent capability profiles for the generator itself
- `.agent/skills/` — skill definitions for the generator (TUI designer, automation engine, parity engine, UX engineering)
