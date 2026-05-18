# TASKS.md — Active Work

## Milestone: {{MILESTONE}}

### In Progress
- [ ] Review all generated context files — correct anything that doesn't match the project
- [ ] Verify SECURITY.md threat model is complete for this project
- [ ] Set up dev environment per ENVIRONMENTS.md

### Backlog — Foundation
- [ ] Confirm architecture decisions in CONTEXT.md; log any changes to memory/decisions/
- [ ] Define data models and API contracts before implementation
- [ ] Implement stack-specific lint configs (ESLint, Ruff, etc.) to enforce quality locally
- [ ] Set up CI pipeline with lint, test, and security audit gates
- [ ] Configure observability stack per OBSERVABILITY.md{{INTAKE_TASKS}}

### Backlog — Skills
{{SKILL_BACKLOG}}

### Backlog — Launch readiness
- [ ] All QUALITY.md gates passing
- [ ] Load test performed and baseline documented
- [ ] Runbook written: deploy, rollback, incident response
- [ ] Staging validated before production promotion

### Done
- [x] Project bootstrapped ({{DATE}})

---
*Update after every agent session. A task is not done until QUALITY.md gates pass.*
*ESCALATE items in SESSION.md take priority over all backlog work.*
