<div align="center">

# Msingi

**Context engineering infrastructure for AI agent sessions.**

*Msingi* is Swahili for **foundation** — the groundwork you lay before building.

[![License: MIT](https://img.shields.io/badge/license-MIT-teal.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-blue.svg)](bootstrap-agent.ps1)
[![Platform: macOS/Linux](https://img.shields.io/badge/platform-macOS%20%2F%20Linux-green.svg)](msingi.sh)
[![Version](https://img.shields.io/badge/version-3.6.0-orange.svg)](#)

**Built in Accra. Designed for everywhere.**

</div>

---

## The problem

The real cost of AI coding tools isn't the subscription — it's the tokens you burn on unstructured sessions.

Every session that starts cold, rediscovers the architecture, re-reads files already read, and remakes decisions already made is a session where your budget goes to exploration instead of creation. Multiply that across a team, across months, across every developer who can't afford to burn tokens on context re-establishment, and the cost is not just financial — it is a barrier.

AI agents are powerful. But without a foundation to work from, they repeat the same exploration every time they start.

**Msingi generates that foundation in 60 seconds.**

---

## What it generates

Run `msingi` once at the start of a project. It asks 15 questions and writes the entire context engineering infrastructure your agents need:

```
your-project/
├── CONTEXT.md          ← canonical truth: architecture, NFRs, stack
├── TASKS.md            ← active milestone and backlog
├── DOMAIN.md           ← business domain: rules, concepts, what good looks like
├── WORKSTREAMS.md      ← parallel agent coordination: scope, phases, merge checkpoints
├── DISCOVERY.md        ← exploration log: variants tried, hypotheses, experiments
├── SECURITY.md         ← threat model shaped by your project type and intake answers
├── QUALITY.md          ← production quality gates agents self-verify before marking done
├── ENVIRONMENTS.md     ← dev/staging/production strategy
├── OBSERVABILITY.md    ← logging, metrics, alerting specification
├── agents/             ← per-agent pointer files (Claude Code, Gemini CLI, Codex, …)
├── skills/             ← capability library: folders with contracts + confidence-weighted gotchas
│   └── <skill-id>/
│       ├── SKILL.md       — interface, acceptance criteria, quick start
│       ├── gotchas.md     — failure patterns with confidence scores (●●●●● → ●○○○○)
│       ├── scripts/       — helper scripts agents can run
│       └── outputs/       — structured results from prior executions
├── scratchpads/        ← per-agent working memory and session handoffs
│   └── <agent>/
│       ├── SESSION.md     — end-of-session handoff with cost + leverage tracking
│       └── NOTES.md       — tiered persistent memory (active + archive tiers)
└── memory/
    └── decisions/      ← append-only ADR log with supersedes chains
```

Every file is generated from your answers — project type, intake questions (audience, auth, sensitive data, deployment target, scale), agents, and inferred skills. Nothing generic.

---

## Why this is different

### Context engineering, not just templates

The files Msingi generates are not documentation templates. They are a **context engineering system** — designed around how AI agents actually consume information.

- **Recency-first session start:** agents read SESSION.md before CONTEXT.md — dynamic state before static context
- **Context budget rules:** what to always include, what to fetch selectively, what to compress, what never to load wholesale
- **Skills as beliefs:** gotchas carry confidence scores (●●●●● critical → ●○○○○ weak), trigger keywords, and update instructions — adapted from the ECC instincts architecture
- **Tiered memory:** NOTES.md targets under 300 lines; older observations compress to NOTES-archive.md — session-start load cost stays flat regardless of project age

### Parallel agent coordination

Every project generates WORKSTREAMS.md — scope boundaries per agent, phase gates, and merge checkpoints. The Karpathy model: carve the codebase into parallel non-conflicting workstreams. Agents own exclusive write scope. Humans review at merge checkpoints, not after every commit.

### Token cost awareness

SESSION.md tracks both efficiency (avoidable re-reads, context establishment cost) and leverage (what was discovered beyond the task). Token throughput is the new GPU utilisation — idle budget is missed opportunity.

### Offline. No cloud dependency. Free.

Msingi generates files and exits. No API calls. No accounts. No runtime. Works on a laptop in Accra on a bad connection as well as it does anywhere else.

---

## Installation

### Windows (PowerShell 7)

```powershell
git clone https://github.com/xdagee/msingi
cd msingi
.\Install.ps1
# New terminal window:
bootstrap
```

### macOS / Linux (Bash 4+)

```bash
git clone https://github.com/xdagee/msingi
cd msingi
chmod +x msingi.sh
./msingi.sh
```

Or add to your PATH for global use:

```bash
sudo ln -s "$(pwd)/msingi.sh" /usr/local/bin/msingi
msingi
```

**Requirements:** Bash 4+ (macOS ships Bash 3 — `brew install bash`), or PowerShell 7+ on Windows.

---

## Usage

```bash
msingi              # guided mode — 7 screens, ~60 seconds
msingi --dry-run    # preview every file without writing anything
msingi --help
```

The tool asks:

1. **Mode** — new project or existing codebase overlay
2. **Type** — web app, API service, ML/AI, CLI tool, full-stack, Android (up to 2 for hybrid)
3. **Details** — name, description, stack, milestone, target directory
4. **Smart intake** — audience, authentication, sensitive data, deployment target, scale
5. **Agents** — which of the 6 registered agents (Claude Code, Gemini CLI, Codex, Opencode, Qwen Code, Antigravity)
6. **Skills** — inferred from your description and stack (61 skills, type-scoped, baseline-guaranteed)
7. **Review + confirm** — full summary before anything is written

---

## Supported agents

| Agent | Config file | Docs |
|---|---|---|
| Claude Code | `agents/CLAUDE.md` | [code.claude.com](https://code.claude.com/docs/en/overview) |
| Gemini CLI | `agents/GEMINI.md` | [geminicli.com](https://geminicli.com/docs/) |
| Codex | `agents/AGENTS.md` | [developers.openai.com](https://developers.openai.com/codex/) |
| Opencode | `agents/opencode.json` | [opencode.ai](https://opencode.ai/docs) |
| Qwen Code | `agents/QWEN.md` | [qwenlm.github.io](https://qwenlm.github.io/qwen-code-docs/en/users/overview/) |
| Antigravity | `agents/ANTIGRAVITY.md` | [antigravity.google](https://antigravity.google/docs/get-started) |

---

## Ethos

*Msingi exists because the real cost of AI coding tools isn't the subscription — it's the tokens you burn on unstructured sessions.*

*Every session that starts cold, rediscovers the architecture, re-reads files already read, and remakes decisions already made is a session where your budget goes to exploration instead of creation.*

*Msingi generates the context engineering infrastructure that makes every agent session start from knowledge. The canonical context. The skill contracts. The gotchas, weighted by confidence. The workstream boundaries. The domain understanding. The session handoff. The memory.*

*It takes 60 seconds to run. It works offline. It produces no cloud dependency. It costs nothing.*

*The constraints that shaped it — bandwidth limits, Windows-native tooling, local LLM backends, cost-aware token management — are not limitations. They are design decisions that make it work for everyone, not just people with unlimited API budgets.*

*Built in Accra. Designed for everywhere.*

---

## Roadmap

- [x] PowerShell 7 (Windows) — v3.6.0
- [x] Bash (macOS / Linux) — v3.6.0
- [ ] Go rewrite with Bubble Tea TUI — v1.0.0 (in progress)
  - Single binary, zero runtime dependencies
  - Cross-platform via goreleaser
  - Full interactive TUI with live sidebar and resize support

---

## Contributing

Msingi is open to contributions that make it more useful for more developers — especially those building in constrained environments.

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**What we welcome:**
- New project types (beyond the current 6)
- New agent registrations in `agents.json`
- New skills in `skills.json` with accurate trigger patterns
- Gotcha seeds for underrepresented categories
- Translations of the manifesto README

**What we won't accept:**
- Cloud dependencies or API calls in the generator
- Features that only work on high-bandwidth connections
- Anything that requires a paid account to use

---

## Acknowledgements

Msingi builds on ideas from:
- [everything-claude-code](https://github.com/affaan-m/everything-claude-code) — instincts architecture and confidence scoring model
- Karpathy's context engineering framing — parallel workstreams, token leverage
- Andrej Karpathy's principle: *"context engineering is the delicate art and science of filling the context window with just the right information for the next step"*
- Debois's 4 Patterns of AI-Native Development — delivery → discovery shift
- Ubuntu philosophy — *I am because we are*

---

## Version history

| Version | Changes |
|---|---|
| **3.7.0** | **Renamed Bootstrap Agent → Msingi** (Swahili: "foundation"). Independent terminal launch: `msingi` now detects when running in an existing shell and spawns a fresh Windows Terminal tab (wt.exe) or conhost window at clean dimensions — the TUI never wraps in your current session. Animated splash screen with typewriter tagline and "Built in Accra. Designed for everywhere." Upgraded to two-column layout (`Write-TwoColumn`) — sidebar and content rendered simultaneously via cursor positioning with a live project summary panel that updates as you fill in details. Completion panel upgraded to full teal `╔═╗` box with brand border, subtitle row, detail lines, and ethos tagline. `Install.ps1` upgraded to register a `msingi` launcher function + `bootstrap` alias. Version: 3.6.0→3.7.0 · 5,009 lines · 27 tests passing. |
| **3.6.0** | ECC-inspired confidence metadata in gotchas.md. Each gotcha is now a belief with evidence: 5 confidence tiers (●●●●● → ●○○○○), trigger keywords, last_seen, status. All 9 skill categories seeded with structured What/Why/Prevention entries. |
| **3.5.0** | WORKSTREAMS.md and DOMAIN.md added. Parallel agent coordination with scope ownership, phase gates, merge checkpoints. Pedagogical domain context for teaching agents the business domain. Token leverage note in SESSION.md. |
| **3.4.0** | Token cost management. SESSION.md context cost log. NOTES.md tiered memory with archive compression. SKILL.md Quick start section with category-specific interface + #1 gotcha. |
| **3.3.0** | Context engineering principles applied from LlamaIndex article. Recency-first session start. Context budget rules. skills/outputs/ folder for compressed execution results. |
| **3.2.0** | Debois Pattern 3: DISCOVERY.md exploration log. Pattern 2: ADR template with Supersedes chains and Spec reference field. |
| **3.1.0** | Skills-as-folders architecture. Each skill gets scripts/, assets/, references/. gotchas.md seeded per category. /careful and /freeze on-demand hooks. |
| **3.0.0** | Hybrid type composition. Smart intake (5 questions). 7-screen TUI with persistent header bar and step sidebar. v3 colour palette with true-colour ANSI. |

---

<div align="center">

*Msingi — the foundation you lay before you build.*

**Built in Accra. Designed for everywhere.**

</div>
