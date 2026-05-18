# OBSERVABILITY.md — Logging, Metrics, and Alerting

**Project:** {{PROJECT_NAME}}
**Type:** {{PROJECT_TYPE_LABEL}}

> Defines what the system must emit and what must be monitored.
> Agents read this before implementing any logging, metrics, or health check logic.
> Observability is not optional — it is a production requirement.

---

{{OBSERVABILITY_FOCUS}}

---

## General logging rules (all project types)

### What to log
- Significant business events (user registered, order placed, model inference complete)
- All errors with full context: error code, message, relevant IDs, stack trace (server-side only)
- Performance measurements for critical paths: duration, resource consumed
- Security events: login attempt, permission denied, token issued/revoked

### What never to log
- Passwords, tokens, API keys, or any credential — even partially
- Full PII: names, emails, phone numbers, addresses in production logs
- Payment card data (PCI scope — log only masked values if required)
- Raw request bodies that may contain any of the above

### Log format
Structured JSON preferred. Every log entry must include:
`timestamp` (ISO 8601), `level`, `service`, `request_id` (where applicable), `message`.

---

## Application Legibility
The system must be transparent to both humans and agents during runtime.
- **Correlation IDs:** Every external request must generate or inherit a trace ID passed to all downstream services and logs.
- **Health endpoints:** The system must expose a `/_health` or similar endpoint returning component status and version.
- **Readiness/Liveness:** For orchestrated deployments (e.g., Kubernetes), expose distinct liveness and readiness probes.

---

## Tooling decisions (fill in before first production deploy)

| Concern | Tool chosen | Rationale | ADR reference |
|---------|-------------|-----------|---------------|
| Log aggregation | *(define)* | | |
| Metrics / APM | *(define)* | | |
| Error tracking | *(define)* | | |
| Alerting | *(define)* | | |
| Uptime monitoring | *(define)* | | |

Log tooling decisions in memory/decisions/ with Severity: HIGH.

---

## Alert runbook stubs

For each alert below, create a runbook entry in memory/decisions/ before going live:
- What does this alert mean?
- What are the first 3 steps to diagnose?
- Who is responsible for responding?
- What is the escalation path if not resolved in 30 min?
