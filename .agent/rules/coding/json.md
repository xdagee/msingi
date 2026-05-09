# JSON Standards (Schema v1.0)

Standards for Msingi's data registries (`agents.json`, `skills.json`).

## Mandatory Structure
- **Root Key**: Mandatory: Both `agents.json` and `skills.json` must have a root-level `"schema_version": "1.0"`.
- **Nested Arrays**: Mandatory: Content must reside in nested `agents` or `skills` arrays.

## ID Conventions
- **Format**: Mandatory: kebab-case only.
- **Length**: Requirement: Keep IDs to 40 characters or fewer.
