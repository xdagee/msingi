---
name: test-harness
description: Use when creating, maintaining, or running the Msingi validation test suite for dual-script parity and schema compliance.
---

# Test Harness Skill

Create and maintain the Msingi validation test suite ensuring dual-script parity and schema compliance.

## Role

You are the **Test Architect**. Your goal is to build a comprehensive, deterministic test suite that validates Msingi's cross-platform output and data integrity.

## Context

Msingi references a `python3 tests/test_suite.py` test suite across all workflows, rules, and documentation. The suite targets 50 tests (upgraded from 27 at v3.8.1) using `pytest`. The test suite is the single gate that prevents regressions in the dual-script architecture.

## Instructions

1. **Test Suite Structure**:
   - Location: `tests/test_suite.py` (main entry point).
   - Framework: `pytest` with clear test class organization.
   - Categories: Core Parity, Format Validation, Schema Compliance, TUI Logic, Inference Engine.

2. **Core Parity Tests**:
   - Mandatory: For each `Build-*Md` function, assert that PS7 and Bash produce byte-identical output for the same inputs.
   - Pattern: Use subprocess calls to run both scripts in `--dry-run` mode, capture output, and diff.
   - Coverage: All 25+ builder functions must have corresponding parity assertions.

3. **Schema Compliance Tests**:
   - Mandatory: Validate `agents.json` and `skills.json` against their v1.0 schemas.
   - Checks: Root `schema_version`, required fields per entry, unique IDs (no duplicates), kebab-case format, ID length ≤40 chars.
   - Regex Validation: Every `trigger` field must compile as a valid regex.

4. **Format Validation Tests**:
   - Mandatory: PS7 here-string closers (`"@`) at column 0.
   - Mandatory: No backtick escapes inside here-strings.
   - Mandatory: CRLF line endings in `msingi.ps1`.
   - Mandatory: Bash syntax check (`bash -n msingi.sh` exit code 0).

5. **Inference Engine Tests**:
   - Mandatory: Given a known description + stack string, assert the correct skills are inferred.
   - Coverage: At least one test per skill category (auth, data, api, ui, ml, infra, messaging, testing, android, core).

6. **Test Isolation**:
   - Requirement: Ensure tests are read-only — they must leave repository state unchanged.
   - Pattern: Use temporary directories for any file generation.
   - Mandatory: Clean up all temp files in teardown.

7. **CI Compatibility**:
   - Pattern: Tests must run headlessly without TTY.
   - Mandatory: Exit with non-zero code on any failure.
   - Mandatory: Output results in a format parseable by CI systems.
