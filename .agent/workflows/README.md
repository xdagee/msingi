# Msingi Workflow Catalog

Step-by-step procedures for common maintenance and development tasks in Msingi.

## Routine Development
- [**Dual-Script Parity**](dual-script-parity.md) — verifying Bash and PS7 scripts produce identical output.
- [**Audit Parity**](audit-parity.md) — post-edit logic and output audit procedure.
- [**Data Validation**](data-validation.md) — verifying `agents.json` and `skills.json` schema compliance.

## Extending Msingi
- [**Add Agent**](add-agent.md) — procedure for registering new AI agents.
- [**Add Skill**](add-skill.md) — procedure for adding new inference skills.
- [**Add Skill Gotcha**](add-skill-gotcha.md) — seeding gotchas for specific skills.

## Release & Quality
- [**Test Suite**](test-suite.md) — executing the full Msingi validation suite.
- [**Installer Test**](installer-test.md) — validating `install.ps1` in clean environments.
- [**Version Bump**](version-bump.md) — synchronizing version strings across the repo.
- [**Release**](release.md) — the end-to-end release process.

---
*For development rules, see [.agent/rules/](../rules/README.md)*
