# Supported Agents

Msingi supports a wide range of AI coding agents, providing custom configuration files and instructions for each.

| Agent | Config file | Docs |
|---|---|---|
| Claude Code | `agents/CLAUDE.md` | [code.claude.com](https://code.claude.com/docs/en/overview) |
| Gemini CLI | `agents/GEMINI.md` | [geminicli.com](https://geminicli.com/docs/) |
| Codex | `agents/AGENTS.md` | [developers.openai.com](https://developers.openai.com/codex/) |
| Opencode | `agents/opencode.json` | [opencode.ai](https://opencode.ai/docs) |
| Qwen Code | `agents/QWEN.md` | [qwenlm.github.io](https://qwenlm.github.io/qwen-code-docs/en/users/overview/) |

## Role Taxonomy
Agents are explicitly classified by their roles to enable effective swarm orchestration:
- **Coordinator**: Manages high-level intent and task delegation.
- **Planner**: Designs technical implementation plans.
- **Executor**: Generates code and verifies against contracts.

Detailed role configurations are stored in `agents.json`.
