# Rule: Data Integrity (Msingi JSON)

Governs the structure and content of Msingi's capability registries.

## Scope

- **Files**: `agents.json`, `skills.json`
- **Subagents**: Capability Archivist

## Metadata

- **Maintainer**: Capability Archivist
- **Schema Version**: 1.0
- **Status**: Stable

## Context

These files drive the inference engine and the context scaffold generation. Integrity is critical for accurate project initialization.

## Schema Compliance

- **Root Version**: Mandatory: Always include `"schema_version": "1.0"` at the JSON root.
- **Nested Structure**: Mandatory: Store `agents` and `skills` in their respective nested arrays.
- **Required Fields (Agents)**: Mandatory: Every agent must have `id`, `name`, `file`, `scratchpad`, `category`, and `docsUrl`.
- **Required Fields (Skills)**: Mandatory: Every skill must have `id`, `name`, `category`, and `trigger`.

## Inference Triggers

- **Format**: Mandatory: Triggers must be case-insensitive regular expressions.
- **Precision**: Standards: Use precise boundaries (e.g., `^android` or `\bkotlin\b`) to prevent false positives.

## Skill Categories

- **Registry**: Mandatory: Use only existing categories (`frontend`, `backend`, `cloud-deployment`, `mobile-dev`, `auth-security`, `observability`).
- **Extensions**: Mandatory: New categories require corresponding entries in `Build-SkillGotchas` in both scripts.

## Confidence Model

- **Indicator**: Standards: Use Unicode circles for confidence (●●●●● for Foundation, ●○○○○ for Experimental).

## Verification

- **Validation**: Mandatory: Run the following command after any edit:
  `pwsh -Command "$data = Get-Content agents.json | ConvertFrom-Json; if ($data.schema_version -ne '1.0' -or -not $data.agents) { throw 'Invalid schema' }"`
- **Uniqueness**: Prohibition: Duplicate `id` values are strictly forbidden in any nested array.
