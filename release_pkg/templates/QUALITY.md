# QUALITY.md — Production Quality Gates

**Project:** {{PROJECT_NAME}}
**Type:** {{PROJECT_TYPE_LABEL}}

> These are not suggestions. A feature is not complete until every applicable
> gate below is checked. Agents self-verify — do not mark done and move on.
> Gates that cannot be met without changing requirements trigger an ESCALATE.

---

{{QUALITY_GATES}}

---

## Gate verification process

When an agent completes a feature:
1. Read through every gate in the relevant section above
2. For each gate: confirm it passes, or document why it does not apply
3. Write verification results to scratchpads/[agent]/NOTES.md
4. If any gate fails: either fix it (preferred) or log the exception in memory/decisions/
   with Severity: HIGH and the rationale for accepting the exception
5. Only then mark the task done in TASKS.md

## Exceptions
Any accepted quality exception must be logged in memory/decisions/ with:
- Which gate was not met
- Why it was accepted
- What the remediation plan is and by when
- Severity: HIGH minimum (CRITICAL if security-related)

## Entropy Control (Golden Principles)
Codebases naturally degrade over time. Agents must actively fight entropy by enforcing these golden principles when modifying existing code:
- **Centralize shared utilities:** If you see the same logic in two places, extract it to a shared module.
- **Prune dead code:** If you replace a function or deprecate a feature, delete the old code immediately. Do not leave it commented out.
- **Refactor as you go:** If you touch a file that violates current style or architecture standards, upgrade it to the new standard as part of your PR.
{{ENTROPY_CONTROL}}
