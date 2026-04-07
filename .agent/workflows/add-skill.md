---
description: Guide for adding a new skill to Msingi
---

# Workflow: Add-Skill

Follow these steps to add a new skill to the Msingi context generator.

1.  **Define the Skill ID**. Choose a unique, lowercase, hyphenated ID (e.g., `vector-db`, `auth-clerk`).
2.  **Edit `skills.json`**. Add the new skill entry.
    - `id`: The unique ID.
    - `name`: Human-readable name (e.g., "Vector Database").
    - `category`: Select from existing categories (mobile, frontend, etc.).
    - `triggers`: A regex pattern (e.g., `(?i)vector|pinecone|weaviate`).
3.  **Validate JSON**. Confirm the file is still valid.
    ```powershell
    Get-Content skills.json | ConvertFrom-Json
    ```
4.  **Implement in `msingi.ps1`**.
    - Find the `Build-SkillGotchas` function.
    - Add a new `case` or `if` block for your skill ID.
    - Provide 3-5 structured gotchas (What/Why/Prevention).
5.  **Sync to `msingi.sh`**.
    - Mirror the same gotchas in the Bash script.
    - Ensure identical wording and format.
6.  **Run Test Suite**. Verify that the new skill doesn't break parsing.
    // turbo
    ```powershell
    python3 tests/test_suite.py
    ```
7.  **Commit**. Use a feat/skill commit message.
    ```bash
    feat(skill): add <id> to skills engine
    ```
