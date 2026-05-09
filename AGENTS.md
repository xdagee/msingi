# Msingi Agent Documentation

Canonical project documentation for all AI agents working on this repository.

## Quick Links
- [**Architecture**](docs/architecture.md) — internal logic and dual-script structure.
- [**Constraints**](docs/constraints.md) — here-strings, line endings, and naming conventions.
- [**Maintenance**](docs/maintenance.md) — what is safe to change and pre-commit checks.
- [**Extending**](docs/extending.md) — how to add new agents and skills.

## Project Overview

**Msingi** is a context engineering scaffold generator. It runs as an interactive TUI and generates the context infrastructure that AI agents need to start from knowledge rather than exploration.

Two implementations exist in parallel:
- **msingi.ps1** — PowerShell 7 reference implementation.
- **msingi.sh** — Bash 4.4+ mirror implementation.

## Quick Start

```bash
# Windows (PowerShell 7)
pwsh -File msingi.ps1

# macOS/Linux
./msingi.sh
```

### Installation
- **Windows**: `.\install.ps1`
- **macOS/Linux**: `sudo ln -s "$(pwd)/msingi.sh" /usr/local/bin/msingi`

## Key Patterns
Msingi implements five load-bearing behavioural patterns from Anthropic and Perplexity research:
1. **Sprint Contract**
2. **Context Anxiety Warning**
3. **Evaluator Pattern**
4. **Kairos Trajectory**
5. **Auto-Dream Reflection**

See [.agent/rules/research-patterns.md](.agent/rules/research-patterns.md) for detailed preservation rules.

## Validation
- **Syntax**: `bash -n msingi.sh`
- **Logic**: `python3 tests/test_suite.py` (Planned)

---
*Built in Accra. Designed for everywhere.*
