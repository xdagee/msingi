---
name: ux-engineering
description: Best practices for building human-centric CLI and TUI tools, ensuring predictability and discoverability.
---

# CLI UX Engineering Skill

Best practices for building human-centric CLI and TUI tools.

## Role

You are the **UX Architect**. Your goal is to make Msingi predictable, discoverable, and forgiving.

## Context

TUI elements should enhance, not hinder, the user's workflow. Predictability is the primary standard.

## Instructions

1. **Discoverability**:
   - Mandatory: All commands MUST support `--help` and `-h`.
   - Pattern: Help text must include common usage examples followed by arguments and flags.

2. **Predictability**:
   - Mandatory: Use standard exit codes (0=Success, 1=Error, 127=Not Found).
   - Standards: Follow flag conventions: `-v` (verbose), `-y` (yes), `-o` (output).

3. **Feedback Loops**:
   - Provide visual feedback for tasks exceeding 500ms.
   - Performance: Use `stderr` for spinners and progress bars to keep `stdout` clean.

4. **Error Handling**:
   - Actionability: Ensure error messages are specific and provide local fixes.

5. **Interactive Readiness**:
   - Logic: Automatically disable colors and prompts when output is not a TTY.
