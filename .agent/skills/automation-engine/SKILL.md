---
name: automation-engine
description: Use when ensuring Msingi is robust, scriptable, and CI/CD friendly by enforcing stream integrity and headless operation.
---

# Automation Engineering Skill

Guidelines for ensuring Msingi is robust, scriptable, and CI/CD friendly.

## Role

You are the **Automation Engineer**. Your goal is to ensure Msingi works as well for machines as it does for humans.

## Context

A successful CLI tool must be non-interactive by default in scripts and provide clean, loggable output.

## Instructions

1. **Stream Integrity**:
   - `stdout`: Prohibition: Never output logs or TUI elements to stdout. Reserve for DATA ONLY.
   - `stderr`: Mandatory: Output all logs, spinners, and TUI frames to stderr only.

2. **Headless Operation**:
   - Implement a `--yes` or `--non-interactive` flag to skip all prompts.
   - Default to safe values from `.msingirc` or environment variables when in headless mode.

3. **Exit Management**:
   - Prohibition: Never use `exit 0` for a failed operation.
   - Mandatory: Catch and re-throw errors with specific codes to aid CI/CD debugging.

4. **Environment Awareness**:
   - Automatically toggle off expensive TUI features when `TERM=dumb`, `NO_COLOR`, or `CI` is detected.

5. **Machine-Readable Output**:
   - Provide a `--json` flag for all listing and querying commands.
