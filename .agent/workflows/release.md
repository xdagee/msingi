---
description: Process for releasing a new version of Msingi
---

# Workflow: Release Msingi

Standard procedure for cutting a new release of the Msingi foundation generator.

1.  **Sync Branch**. Ensure you are on the `main` branch and it is up to date.
    ```bash
    git checkout main && git pull
    ```
2.  **Verify Parity**.
    - Confirm all `Build-` functions match between `msingi.ps1` and `msingi.sh`.
    - Check that the `agents.json` and `skills.json` matches are in place.
3.  **Run Tests**. Full suite must pass with 0 errors.
    // turbo
    ```powershell
    python3 tests/test_suite.py
    ```
4.  **Bump Version**. Update `$VERSION = "X.Y.Z"` in:
    - `msingi.ps1` (line ~63)
    - `msingi.sh` (top of file)
    - `README.md` (badges and history table)
5.  **Tag and Commit**.
    ```bash
    git add .
    git commit -m "chore(release): vX.Y.Z"
    git tag -a vX.Y.Z -m "Release vX.Y.Z"
    ```
6.  **Push**.
    ```bash
    git push origin main --tags
    ```
7.  **Announce**. Update the internal changelog and notify the team.
