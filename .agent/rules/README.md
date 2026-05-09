# Msingi Rule Catalog

Governance rules for the Msingi repository. These rules ensure cross-platform stability, context engineering quality, and data integrity.

## Core Development
- [**Coding Standards**](coding-standards.md) — entry point for platform-specific (PS7/Bash) coding rules and synchronization logic.
- [**Windows Compatibility**](windows-compatibility.md) — constraints for backslashes, path expansion, and terminal requirements.
- [**Data Integrity**](data-integrity.md) — schema compliance and verification for `agents.json` and `skills.json`.

## Context Engineering
- [**Generated Output Contract**](generated-output-contract.md) — structural invariants for the files Msingi generates (CONTEXT, SECURITY, etc.).
- [**Research Pattern Preservation**](research-patterns.md) — rules for the behavioural research patterns (Sprint Contract, Context Anxiety, etc.).

## Maintenance
- [**Maintainer Redirect**](maintainer.md) — pointer to consolidated maintenance rules.

---
*For procedural steps, see [.agent/workflows/](../workflows/README.md)*
