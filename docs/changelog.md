# Version History

| Version | Changes |
|---|---|
| **4.0.0** | **Agentic Memory Engine.** Synthesized Perplexity's "Agent Skills" and Claude Code's "Kairos/Auto-Dream" research. Introduced Hub-and-Spoke skill folders with `evals/` and `config.json`. Implemented `memory/trajectories/` for intent tracking and `workstreams/INBOX.md` for inter-agent signaling. Formalized Progressive Disclosure and Context Compaction protocols to minimize token tax across long-running projects. |
| **3.11.0** | **Harness Engineering Parity.** Integrated OpenAI Harness Engineering Tier 1-3 protocols (ExecPlans via `PLANS.md`, Entropy Control via `QUALITY.md`, Application Legibility via `OBSERVABILITY.md`, and Doc Gardening). Achieved full generation parity for these protocols across both the PowerShell (`msingi.ps1`) and Bash (`msingi.sh`) implementations. |
| **3.9.0** | **Claude Code Teardown Integration.** Derived from architectural teardowns of modern agent CLI models: Integrated `Agent Roles` taxonomy classifying agents as `coordinator`, `planner`, or `executor`. Implemented `Auto-Dream Memory Consolidation` skill dropping `dream.ps1`/`dream.sh` compaction templates. |
| **3.8.1** | **Production Stabilization & NN/G Agent Framework**. Added `desktop-windows` project type (MVVM WinUI 3 architecture, DLL hijacking threat model, MSIX quality gates). Implemented NN/G's concrete AI agent definition into the core scaffold: all agents are now profiled via `capabilityToAct` and `selfDirection`, and the scaffold config enforces a strict **Agentic Loop Protocol**. Upgraded test suite to a comprehensive 50-test Python (`pytest`) validation harness. |
| **3.7.0** | **Renamed Bootstrap Agent → Msingi** (Swahili: "foundation"). Independent terminal launch. Animated splash screen. Upgraded to two-column layout (`Write-TwoColumn`) with live project summary panel. Completion panel upgraded to full teal `╔═╗` box. `install.ps1` upgraded to register a `msingi` launcher function + `bootstrap` alias. |
| **3.6.0** | ECC-inspired confidence metadata in gotchas.md. 5 confidence tiers (●●●●● → ●○○○○), trigger keywords, last_seen, status. All 9 skill categories seeded with structured What/Why/Prevention entries. |
| **3.5.0** | WORKSTREAMS.md and DOMAIN.md added. Parallel agent coordination with scope ownership, phase gates, merge checkpoints. Token leverage note in SESSION.md. |
| **3.4.0** | Token cost management. SESSION.md context cost log. NOTES.md tiered memory with archive compression. SKILL.md Quick start section. |
| **3.3.0** | Context engineering principles from LlamaIndex. Recency-first session start. Context budget rules. skills/outputs/ folder. |
| **3.2.0** | Debois Pattern 3: DISCOVERY.md exploration log. Pattern 2: ADR template with Supersedes chains. |
| **3.1.0** | Skills-as-folders architecture. Each skill gets scripts/, assets/, references/. /careful and /freeze on-demand hooks. |
| **3.0.0** | Hybrid type composition. Smart intake (5 questions). 7-screen TUI with persistent header bar and step sidebar. v3 colour palette. |
