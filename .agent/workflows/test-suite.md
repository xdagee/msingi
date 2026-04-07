---
description: Execute the full Msingi validation suite for functional and logic parity
---

# Workflow: Msingi Test Suite

Ensure the stability and correctness of `msingi.ps1` and `msingi.sh` before any commit.

## Steps

### 1. Environment Check
- **Shell**: Open PowerShell 7 (required for TUI testing).
- **Python**: Verify `python3` is available in your PATH.
    ```powershell
    python3 --version
    ```

### 2. Execution
- **Run Suite**: Execute the Python test script from the repository root.
    // turbo
    ```powershell
    python3 tests/test_suite.py
    ```

### 3. Analysis & Resolution
- **Pass Criteria**: All 27 tests (Core Parity, Format, etc.) must pass.
- **Fail Correction**: If any test fails, do NOT commit. Check `msingi.ps1` for brace balance, here-string boundaries, or quote parity.
- **Retry**: Re-run the suite until a clean pass is achieved.
