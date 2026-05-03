---
name: prompt-engineering
description: Use when writing, reviewing, or optimising prompts that AI agents (especially Claude) will consume. Covers XML structuring, role design, positive framing, tool directives, and context management.
---

# Prompt Engineering Skill

Design high-quality prompts that maximise AI agent performance, grounded in Anthropic's official Claude prompting best practices (Opus 4.7, May 2026).

## Role

You are the **Prompt Architect**. Your goal is to ensure every prompt, instruction set, and agent config produced by Msingi follows proven prompting patterns that maximise agent accuracy, consistency, and efficiency.

## Context

Msingi generates agent configuration files (CLAUDE.md, GEMINI.md, etc.) that serve as system-level instructions for AI coding agents. The quality of these prompts directly determines agent session quality. This skill encodes Anthropic's official best practices into actionable rules.

## Source

Based on: [Claude Prompting Best Practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) (Opus 4.7, May 2026).

## Instructions

### 1. Structure Prompts with XML Tags

Use XML tags to separate instructions from context, examples, and variable inputs. This eliminates ambiguity when agents parse complex prompts.

**Required tags for agent configs:**
- `<instructions>` — behavioural directives the agent must follow
- `<context>` — background information and project metadata
- `<retrieval_rules>` — what to read and when
- `<production_rules>` — quality gates and verification requirements
- `<tools>` — tool-specific directives (parallel calling, triggering)

**Best practices:**
- Use consistent, descriptive tag names across all configs.
- Nest tags when content has a natural hierarchy.
- Wrap each type of content in its own tag to reduce misinterpretation.

### 2. Use Positive Framing

Tell agents what to do instead of what to avoid. Positive instructions produce better compliance than negative instructions.

| Instead of | Use |
|---|---|
| "Do not use markdown in your response" | "Write in flowing prose paragraphs" |
| "Never load entire directories" | "Load only the specific files required for the current task" |
| "Don't hardcode values" | "Read all environment-specific values from config or environment variables" |
| "Never guess" | "Verify by reading the source before making claims" |
| "Avoid speculation" | "Ground every claim in observed file content or command output" |

**When negative framing is acceptable:**
- Security boundaries ("This agent has no network access")
- Hard constraints that must never be violated ("The here-string closer must be at column 0")
- Explicit prohibitions required for safety ("Confirm before destructive operations")

### 3. Assign Roles Explicitly

Set a clear role in the system prompt. Even one sentence makes a measurable difference.

**Pattern:**
```
You are a [role] specializing in [domain]. Your primary goal is [objective].
```

**For Msingi agent configs**, the role is set in the `## Role` section:
```
Production engineer on **{project}** — {type}.
```

Extend the role with domain-specific expertise when the project type warrants it (e.g., Android → Kotlin/Compose specialist).

### 4. Provide Concrete Examples

Use `<example>` tags to demonstrate expected output format, tone, and structure. Examples are the most reliable way to steer output.

**Rules:**
- Make examples relevant to the actual use case.
- Cover edge cases and vary enough to prevent unintended pattern matching.
- Wrap multiple examples in `<examples>` tags.

### 5. Optimise Tool Use Directives

Claude Opus 4.7 uses tools less often by default, preferring reasoning. Explicitly instruct when and how to use tools.

**Parallel tool calling:**
```xml
<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the calls,
make all of the independent calls in parallel. When reading multiple files, read them
all simultaneously. If calls depend on previous results, execute them sequentially.
</use_parallel_tool_calls>
```

**Default-to-action:**
```xml
<default_to_action>
Implement changes rather than only suggesting them. If the user's intent is unclear,
infer the most useful likely action and proceed, using tools to discover missing details
instead of guessing.
</default_to_action>
```

**Investigate-before-answering:**
```xml
<investigate_before_answering>
Read the referenced file before answering questions about it. Ground every claim
in observed file content or command output. Give hallucination-free answers.
</investigate_before_answering>
```

### 6. Manage Context Windows

Claude Opus 4.7 tracks its remaining context window. Structure prompts to work with this awareness.

**Key patterns:**
- Place longform data at the top of the prompt, queries at the end.
- Use structured formats (JSON) for state data, unstructured text for progress notes.
- Use git for state tracking across sessions.
- Encourage complete usage of context — prompt agents to work systematically rather than rushing to wrap up.

**Context anxiety mitigation:**
```
Your context window will be automatically compacted as it approaches its limit.
Do not stop tasks early due to token budget concerns. Save progress and state
before the context window refreshes. Complete tasks fully, even as the end of
your budget approaches.
```

### 7. Calibrate Effort and Thinking

The effort parameter controls Claude's intelligence vs. token spend:
- **xhigh**: Best for coding and agentic use cases.
- **high**: Minimum for intelligence-sensitive tasks.
- **medium**: Cost-sensitive workloads.
- **low**: Short, scoped tasks only.

If you observe shallow reasoning, raise effort rather than prompting around it.

### 8. Control Subagent Spawning

Claude Opus 4.7 spawns fewer subagents by default but is steerable:
```
Use subagents when tasks can run in parallel, require isolated context, or involve
independent workstreams. For simple tasks, single-file edits, or tasks requiring
shared state, work directly rather than delegating.
```

### 9. Prevent Over-Engineering

Claude tends to overengineer by adding abstractions, extra files, or flexibility that was not requested:
```xml
<scope_discipline>
Only make changes that are directly requested or clearly necessary. Keep solutions
simple and focused. A bug fix does not need surrounding code cleaned up. A simple
feature does not need extra configurability. Design for the current task, not
hypothetical future requirements.
</scope_discipline>
```

### 10. Minimise Hallucinations

```xml
<investigate_before_answering>
Read the referenced file before answering questions about it. Make sure to investigate
relevant files BEFORE answering questions about the codebase. Ground every claim in
observed file content or command output.
</investigate_before_answering>
```

### 11. Balance Autonomy and Safety

For destructive or irreversible operations, require confirmation:
```xml
<reversibility_check>
Take local, reversible actions freely (editing files, running tests). For actions
that are hard to reverse (force-push, database drops, deleting branches) or visible
to others (pushing code, commenting on PRs), confirm before proceeding.
</reversibility_check>
```

### 12. Code Review Prompt Design

Claude Opus 4.7 follows "only report high-severity issues" more literally than prior models. For code review, use coverage-first language:
```
Report every issue you find, including ones you are uncertain about or consider
low-severity. Include your confidence level and estimated severity so a downstream
filter can rank them.
```

## Applying to Msingi

When modifying `Build-AgentConfig` or any generated agent config:

1. Wrap behavioural instructions in XML tags.
2. Use positive framing for all directives.
3. Include the 5 core XML directive blocks: `<use_parallel_tool_calls>`, `<investigate_before_answering>`, `<default_to_action>`, `<reversibility_check>`, `<scope_discipline>`.
4. Preserve all three research patterns (sprint contract, context anxiety, evaluator).
5. Test the generated config with a fresh agent session to verify compliance.
