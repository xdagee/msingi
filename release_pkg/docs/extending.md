# Extending Msingi

Guide for adding new capabilities and agents to the Msingi engine.

## Adding a New Skill
1. **Registry**: Add an entry to `skills.json` following the v1.0 schema.
2. **Gotchas**: Add seed gotchas to `Build-SkillGotchas` in **both** `msingi.ps1` and `msingi.sh`.
3. **Verification**: Run the test suite and validate JSON schema.

## Adding a New Agent
1. **Registry**: Add an entry to `agents.json`.
2. **Config**: Handle any special config formats in the `Build-AgentConfig` emit loop in both scripts.
3. **Roles**: Update `.agent/agents.md` if a new role is introduced.

## Schema Reference (v1.0)
Detailed schema requirements are documented in [.agent/rules/coding/json.md](../.agent/rules/coding/json.md).
