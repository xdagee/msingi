---
description: Audit logic and output parity between msingi.ps1 and msingi.sh
---

This workflow ensures that even as Msingi evolves, its dual-script architecture remains synchronized.

### Trigger
- After modifying `msingi.ps1` or `msingi.sh`.
- When adding new file builders.
- When changing TUI layout or input handling logic.

### Steps

1. **Identify the Change Scope**
   - Review the diff in the primary script (usually `msingi.ps1`).
   - Identify which functional area is affected (Builder, TUI, Inference, Input).

2. **Mirror the Change**
   - Locate the equivalent function or code block in the secondary script.
   - Apply the logic change using the `parity-engine` skill guidelines.

3. **Verify Output Parity**
   - Run both scripts with identical mock inputs (use `--dry-run` or a temp directory).
   - Use `diff` or `Compare-Object` to verify that generated files are identical.
   
// turbo
4. **Run Regression Tests**
   - Execute `python3 tests/test_suite.py` (or `python3 tests/test_navigation.py`).
   - Ensure all tests pass on both platforms.
