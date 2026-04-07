---
description: Guide for adding a new skill to Msingi
---

This workflow guides the addition of a new skill, ensuring it is correctly registered and seeded with gotchas.

### Steps

1. **Define the Skill in skills.json**
   - Add a new JSON object to `skills.json` with a unique ID, category, and trigger regex.
   - Example: `{"id": "new-skill", "name": "New Skill", "category": "api", "trigger": "pattern"}`.

// turbo
2. **Validate skills.json**
   - Run `pwsh -Command "Get-Content skills.json | ConvertFrom-Json"` to ensure valid JSON.

3. **Identify Gotcha Seeds**
   - Research common failure patterns (gotchas) for this skill.
   - Format them with confidence scores (●●●●● to ●○○○○).

4. **Update File Builders**
   - Add the gotcha seed to the `Build-SkillGotchas` function in `msingi.ps1`.
   - **Mirror the change** to the equivalent function in `msingi.sh` (use `audit-parity` workflow).

5. **Verify Inference**
   - Run a dry-run of Msingi with a description that should trigger the new skill.
   - Confirm the skill is listed in the review screen.
