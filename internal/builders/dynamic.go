package builders

import (
	"fmt"
	"strings"
	"time"

	"github.com/xdagee/msingi/internal/engine"
	"github.com/xdagee/msingi/internal/models"
)

// BuildTasksMd generates the TASKS.md file
func BuildTasksMd(e *engine.Engine, p *models.Project) string {
	skillBacklog := ""
	if p.HasSkills {
		skillBacklog = "- [ ] Review skill specs in skills/ — define interfaces before any implementation\n" +
			"- [ ] Implement skills in priority order per skills/README.md\n" +
			"- [ ] Verify each skill against its acceptance criteria before marking done"
	}

	intakeTasks := ""
	if p.NeedsAuth {
		intakeTasks += "\n- [ ] Design and document auth flow before any implementation (login, logout, token lifecycle)"
	}
	if p.HandlesSensitiveData {
		tags := p.SensitiveTags
		if tags == "" {
			tags = "sensitive data"
		}
		intakeTasks += "\n- [ ] Complete sensitive data inventory (" + tags + ") — map all fields before coding"
		intakeTasks += "\n- [ ] Define data retention and deletion policy — log decision to memory/decisions/"
	}

	if p.ScaleProfile == "growth" || p.ScaleProfile == "enterprise" {
		intakeTasks += "\n- [ ] Define SLO targets (uptime, latency p95) and configure alerting before launch"
		intakeTasks += "\n- [ ] Load test at 2x expected peak before promotion to production"
	}
	if p.ScaleProfile == "enterprise" {
		intakeTasks += "\n- [ ] Compliance requirements identified and documented in memory/decisions/"
		intakeTasks += "\n- [ ] Penetration test scheduled before first external release"
	}

	if p.DeploymentTarget == "mobile-store" {
		intakeTasks += "\n- [ ] App store listing and review requirements documented before feature freeze"
		intakeTasks += "\n- [ ] Release signing and keystore management documented in SECURITY.md"
	}
	if p.DeploymentTarget == "on-prem" {
		intakeTasks += "\n- [ ] Deployment runbook written before handoff — install, upgrade, rollback"
		intakeTasks += "\n- [ ] Network and firewall requirements documented in ENVIRONMENTS.md"
	}

	if p.Audience == "public" {
		intakeTasks += "\n- [ ] Abuse prevention strategy defined (rate limiting, CAPTCHA, anomaly detection)"
	}
	if p.SecondaryTypeID != "" {
		intakeTasks += "\n- [ ] Hybrid type integration points identified — document boundary between " + p.TypeLabel + " and " + p.SecondaryTypeLabel + " concerns"
	}

	dateStr := time.Now().Format("2006-01-02")
	milestone := p.Milestone
	if milestone == "" {
		milestone = "v0.1.0 MVP"
	}

	return e.RenderTemplate("TASKS.md", map[string]string{
		"MILESTONE":     milestone,
		"INTAKE_TASKS":  intakeTasks,
		"SKILL_BACKLOG": skillBacklog,
		"DATE":          dateStr,
	})
}

// BuildContextMd generates the CONTEXT.md file
func BuildContextMd(e *engine.Engine, p *models.Project) string {
	stackLines := "- To be defined"
	if p.Stack != "" {
		stackArr := strings.Split(p.Stack, ",")
		stackLines = "- " + strings.Join(stackArr, "\n- ")
	}

	status := "Active - greenfield"
	hybridLine := ""
	if p.SecondaryTypeLabel != "" {
		hybridLine = "\n**Hybrid secondary:** " + p.SecondaryTypeLabel
	}

	audienceLabel := "Not specified"
	if p.AudienceLabel != "" {
		audienceLabel = p.AudienceLabel
	}
	deployLabel := "Not specified"
	if p.DeployLabel != "" {
		deployLabel = p.DeployLabel
	}
	scaleLabel := "Not specified"
	if p.ScaleLabel != "" {
		scaleLabel = p.ScaleLabel
	}

	authLabel := "Not required"
	if p.NeedsAuth {
		authLabel = "Required"
	}

	dataLabel := "None"
	if p.HandlesSensitiveData {
		tags := p.SensitiveTags
		if tags == "" {
			tags = "Yes"
		}
		dataLabel = "Yes — " + tags
	}

	// Stubbing agents and skills for Phase 2 test harness logic until we fully parse them
	agentLines := "- To be defined"
	if p.AgentLines != "" {
		agentLines = p.AgentLines
	}
	docsLines := "- To be defined"
	if p.DocsLines != "" {
		docsLines = p.DocsLines
	}
	skillLines := "- To be defined"
	if p.SkillLines != "" {
		skillLines = p.SkillLines
	}

	dateStr := time.Now().Format("2006-01-02")
	milestone := p.Milestone
	if milestone == "" {
		milestone = "v0.1.0 MVP"
	}

	projName := p.Name
	if projName == "" {
		projName = "Project"
	}
	typeLabel := p.TypeLabel
	if typeLabel == "" {
		typeLabel = "Web"
	}
	description := p.Description
	if description == "" {
		description = "A new multi-agent project."
	}
	architecture := p.Architecture
	if architecture == "" {
		architecture = "Standard architecture"
	}
	nfr := p.NFR
	if nfr == "" {
		nfr = "- Performance: < 2.5s page load"
	}

	return e.RenderTemplate("CONTEXT.md", map[string]string{
		"PROJECT_NAME":        projName,
		"PROJECT_TYPE_LABEL":  typeLabel,
		"HYBRID_LINE":         hybridLine,
		"STATUS":              status,
		"DATE":                dateStr,
		"PROJECT_DESCRIPTION": description,
		"AUDIENCE_LABEL":      audienceLabel,
		"AUTH_LABEL":          authLabel,
		"DATA_LABEL":          dataLabel,
		"DEPLOY_LABEL":        deployLabel,
		"SCALE_LABEL":         scaleLabel,
		"STACK_LINES":         stackLines,
		"ARCHITECTURE":        architecture,
		"NFR":                 nfr,
		"AGENT_LINES":         agentLines,
		"DOCS_LINES":          docsLines,
		"SKILL_LINES":         skillLines,
		"MILESTONE":           milestone,
	})
}

// BuildWorkstreamsMd generates the WORKSTREAMS.md file
func BuildWorkstreamsMd(e *engine.Engine, p *models.Project, agents []models.Agent, skills []models.Skill) string {
	dateStr := time.Now().Format("2006-01-02")
	typeNote := p.TypeLabel
	if p.SecondaryTypeID != "" {
		typeNote += " + " + p.SecondaryTypeLabel
	}

	scopeSuggestions := map[string]string{
		"claude-code": "auth, API layer, business logic",
		"gemini-cli":  "data layer, migrations, schema",
		"codex":       "tests, CI config, tooling scripts",
		"opencode":    "frontend, UI components, styles",
		"aider":       "refactoring, code quality, documentation",
		"qwen-code":   "infrastructure, deployment config",
	}

	wsDefs := ""
	for i, a := range agents {
		scope := "define scope before starting"
		if s, ok := scopeSuggestions[a.ID]; ok {
			scope = s
		}
		
		wsDefs += "\n### WS-" + fmt.Sprintf("%d", i+1) + " — " + a.Name + "\n" +
			"**Agent:** " + a.Name + " (``" + a.File + "``)\n" +
			"**Status:** IDLE\n" +
			"**Scope:** " + scope + "\n" +
			"**Owns:** *(define: which src/ subdirectories or files this workstream exclusively writes)*\n" +
			"**Depends on:** *(list any WS- numbers that must complete a phase before this starts)*\n\n" +
			"**Current task:**\n" +
			"*(describe the specific task currently in progress, or leave blank if IDLE)*\n\n" +
			"**Merge checkpoint:** *(define: what must be true before merging this workstream's output)*\n" +
			"- [ ] Tests pass for owned scope\n" +
			"- [ ] No writes outside owned scope\n" +
			"- [ ] QUALITY.md gates relevant to this scope verified\n" +
			"- [ ] SESSION.md complete with current state\n\n" +
			"**Last active:** —\n" +
			"**Notes:**\n\n" +
			"---\n"
	}

	return e.RenderTemplate("WORKSTREAMS.md", map[string]string{
		"PROJECT_NAME":           p.Name,
		"PROJECT_TYPE_LABEL":     typeNote,
		"DATE":                   dateStr,
		"VERSION":                "1.0.0", // Hardcoded for parity with static files
		"WORKSTREAM_DEFINITIONS": wsDefs,
	})
}

// BuildTrajectoryMd generates the CURRENT.md file
func BuildTrajectoryMd(e *engine.Engine, p *models.Project) string {
	dateStr := time.Now().Format("2006-01-02")
	milestone := p.Milestone
	if milestone == "" {
		milestone = "v0.1.0 MVP"
	}
	return e.RenderTemplate("TRAJECTORY.md", map[string]string{
		"MILESTONE": milestone,
		"DATE":      dateStr,
		"VERSION":   "1.0.0", // Hardcoded for parity
	})
}

// BuildAgentMd generates the agents/<id>.md file
func BuildAgentMd(e *engine.Engine, a *models.Agent, p *models.Project) string {
	heading := strings.ToUpper(strings.TrimSuffix(a.File, ".md"))
	stackLines := "See CONTEXT.md"
	if p.Stack != "" {
		stackLines = strings.Join(strings.Split(p.Stack, ","), ", ")
	}

	return e.RenderTemplate("AGENT.md", map[string]string{
		"AGENT_NAME":          heading,
		"PROJECT_NAME":        p.Name,
		"PROJECT_TYPE_LABEL":  p.TypeLabel,
		"PROJECT_DESCRIPTION": p.Description,
		"STACK_LINES":         stackLines,
		"MILESTONE":           p.Milestone,
		"AGENT_ID":            a.Scratchpad,
		"DOCS_URL":            a.DocsUrl,
	})
}

// BuildSkillSpecMd generates the SKILL.md file
func BuildSkillSpecMd(e *engine.Engine, s *models.Skill, p *models.Project) string {
	guidance := map[string]string{
		"auth":      "Security is non-negotiable. Explain the why: field injection is avoided because it breaks mockability in unit tests. JWTs are signed, not encrypted—PII exposure risk is high. Every auth decision must justify its token cost in the session log.",
		"data":      "Data integrity is the contract. Explain the why: N+1 queries are blocked because they cause linear latency degradation as the dataset grows. Soft-deletes must be filtered in every join to prevent stale data leaks.",
		"api":       "APIs are contracts. Explain the why: consistent error envelopes are required so client-side telemetry can reliably detect failures. 200-with-error is prohibited as it masks failures from load balancers.",
		"ui":        "Components are building blocks. Explain the why: stateless components are preferred because they reduce the surface area for side-effect bugs. Accessibility is a production requirement for WCAG compliance.",
		"ml":        "Pipelines, not magic. Explain the why: data leakage via pre-split shuffling is a critical failure mode that invalidates model evaluation. Every preprocessing step must be serialised with the model weights.",
		"infra":     "Invisible when working. Explain the why: secrets in build args are avoided because they persist in image history layers. Fail loudly on config mismatch to prevent silent misconfiguration in production.",
		"messaging": "Messages are unreliable. Explain the why: idempotency is mandatory because at-least-once delivery guarantees mean messages WILL be repeated. Log every handoff for traceability.",
		"testing":   "Tests are specifications. Explain the why: unit tests must assert on interfaces, not implementations, to avoid brittle tests that break on refactors. Coverage is a quality gate, not a target.",
		"android":   "Main thread is sacred. Explain the why: blocking the main thread for I/O triggers ANRs and destroys user experience. ViewModels must not hold Context references to prevent memory leaks.",
	}

	triggers := map[string]string{
		"auth":      "MAKE SURE to use this skill whenever implementing login, logout, signup, tokens, or access control. Even if not explicitly asked, use it to review existing auth logic. Exclusions: Do NOT use for generic business logic or non-auth database schemas.",
		"data":      "MAKE SURE to use this skill whenever writing database queries, migrations, or ORM models. Use it for any persistence-related task. Exclusions: Do NOT use for in-memory state management or UI data binding.",
		"api":       "MAKE SURE to use this skill whenever building REST/GraphQL endpoints, webhooks, or request validation. Use it to ensure API contract integrity. Exclusions: Do NOT use for internal library functions or CLI-only logic.",
		"ui":        "MAKE SURE to use this skill whenever building UI components, forms, or layouts. Use it to ensure responsiveness and accessibility. Exclusions: Do NOT use for backend business logic or data processing.",
		"ml":        "MAKE SURE to use this skill whenever implementing model inference, pipelines, or preprocessing. Use it to prevent data leakage. Exclusions: Do NOT use for generic data analysis or non-ML script automation.",
		"infra":     "MAKE SURE to use this skill whenever configuring deployments, CI/CD, or secrets. Use it to ensure production readiness. Exclusions: Do NOT use for application-level feature development.",
		"messaging": "MAKE SURE to use this skill whenever implementing queues, events, or async communication. Use it to ensure idempotency. Exclusions: Do NOT use for synchronous request-response API calls.",
		"testing":   "MAKE SURE to use this skill whenever writing tests, mocks, or test infra. Use it to ensure test reliability and coverage. Exclusions: Do NOT use for production code implementation.",
		"android":   "MAKE SURE to use this skill whenever building Android screens, ViewModels, or Compose UI. Use it to handle lifecycle and main-thread safety. Exclusions: Do NOT use for platform-agnostic Kotlin logic.",
	}

	quickStart := map[string]string{
		"auth":      "**Interface:** takes credentials or token → returns auth result + session. **#1 gotcha:** JWTs are signed, not encrypted — never put sensitive data in the payload.",
		"data":      "**Interface:** takes query params → returns typed result or error. **#1 gotcha:** N+1 queries are the silent killer — profile before marking any data feature done.",
		"api":       "**Interface:** HTTP request in → validated response out, consistent error envelope. **#1 gotcha:** returning 200 with an error body breaks all downstream monitoring — use correct status codes.",
		"ui":        "**Interface:** accepts typed props → renders component, emits typed events. **#1 gotcha:** missing loading and error states will crash the UI — always handle all three states.",
		"ml":        "**Interface:** takes typed input tensor/dataframe → returns prediction + confidence. **#1 gotcha:** train/val data leakage — always split before shuffling, never after.",
		"infra":     "**Interface:** declarative config in → provisioned resource out. **#1 gotcha:** secrets in build args get baked into image layers — use runtime env vars or a secrets manager.",
		"messaging": "**Interface:** message in → processed + ack/nack out. **#1 gotcha:** consumers must be idempotent — the same message will be delivered more than once.",
		"testing":   "**Interface:** test subject in → assertion result out. **#1 gotcha:** tests that never assert pass silently — require a minimum assertion count in linter config.",
		"android":   "**Interface:** ViewModel state in → Compose UI out, user events up. **#1 gotcha:** any I/O on the main thread causes an ANR — all data work must run on Dispatchers.IO.",
	}

	hint := "Define constraints before implementing."
	if h, ok := guidance[s.Category]; ok {
		hint = h
	}

	trigger := "Use this skill when implementing " + s.Name + " functionality."
	if s.Description != "" {
		trigger = s.Description
	} else if t, ok := triggers[s.Category]; ok {
		trigger = t
	}

	qs := "**Interface:** define before implementing. **#1 gotcha:** check ``gotchas.md`` before writing any code."
	if q, ok := quickStart[s.Category]; ok {
		qs = q
	}

	shortDesc := p.Description
	if len(shortDesc) > 120 {
		shortDesc = shortDesc[:120] + "..."
	}

	return e.RenderTemplate("SKILL.md", map[string]string{
		"SKILL_NAME":   s.Name,
		"TRIGGER":      trigger,
		"SKILL_ID":     s.ID,
		"CATEGORY":     s.Category,
		"DATE":         time.Now().Format("2006-01-02"),
		"QS":           qs,
		"PROJECT_NAME": p.Name,
		"SHORT_DESC":   shortDesc,
		"HINT":         hint,
	})
}

// BuildSkillGotchasMd generates the SKILL_GOTCHAS.md file
func BuildSkillGotchasMd(e *engine.Engine, s *models.Skill, p *models.Project) string {
	seeds := map[string]string{
		"auth": "\n### G-001 · JWTs are not encrypted — only signed\n" +
			"``confidence: ●●●●● critical``  ``triggers: jwt, token, payload, claims``  ``last_seen: seeded``  ``status: ACTIVE``\n" +
			"``helpful: 0``  ``harmful: 0``\n" +
			"**What:** Sensitive data placed in JWT payload is exposed — base64 is not encryption.\n" +
			"**Why:** JWT signing proves authenticity but not secrecy. Any party can decode the payload.\n" +
			"**Prevention:** Never put PII, secrets, or sensitive business data in a JWT payload. Store a user ID only; fetch sensitive data server-side on each request.\n" +
			"\n### G-002 · OAuth state param not validated → CSRF\n" +
			"``confidence: ●●●●○ high``  ``triggers: oauth, callback, redirect, authorization_code``  ``last_seen: seeded``  ``status: ACTIVE``\n" +
			"``helpful: 0``  ``harmful: 0``\n" +
			"**What:** CSRF attack on the OAuth callback — attacker forces victim to link attacker's account.\n" +
			"**Why:** The ``state`` param exists to bind the request to the initiating session. Skipping the check removes this binding.\n" +
			"**Prevention:** Generate a cryptographically random ``state`` before redirect. Verify it matches exactly on callback. Reject any mismatch.\n" +
			"\n### G-003 · Password reset tokens reused after first use\n" +
			"``confidence: ●●●●○ high``  ``triggers: reset, password, token, forgot``  ``last_seen: seeded``  ``status: ACTIVE``\n" +
			"``helpful: 0``  ``harmful: 0``\n" +
			"**What:** Reset link works multiple times — attacker who intercepts it can use it later.\n" +
			"**Why:** Token not invalidated on first use, or invalidated asynchronously with a race window.\n" +
			"**Prevention:** Mark token used *before* processing the reset. Make tokens single-use and expire in ≤15 minutes. Use constant-time comparison.\n" +
			"\n### G-004 · Raw Authorization header logged in error handlers\n" +
			"``confidence: ●●●●○ high``  ``triggers: log, error, authorization, header, bearer``  ``last_seen: seeded``  ``status: ACTIVE``\n" +
			"``helpful: 0``  ``harmful: 0``\n" +
			"**What:** Bearer tokens appear in logs — accessible to anyone with log access.\n" +
			"**Why:** Error handlers log the full request headers without redacting credentials.\n" +
			"**Prevention:** Strip Authorization header from logs. Log only scheme + first 8 chars: ``Bearer sk-12345...``. Audit log pipeline for credential leakage before first deploy.",
		"data": "\n### G-001 · N+1 query in data loops\n" +
			"``confidence: ●●●●● critical``  ``triggers: loop, forEach, map, list, collection, index``  ``last_seen: seeded``  ``status: ACTIVE``\n" +
			"``helpful: 0``  ``harmful: 0``\n" +
			"**What:** One query fires per iteration instead of one batch query for the whole set.\n" +
			"**Why:** ORM lazy-loading resolves associations inside a loop. Visible in query logs; often invisible until load.\n" +
			"**Prevention:** Enable query logging in dev. Profile every list endpoint before marking done. Use eager loading or a single JOIN. If count > 2× items, investigate immediately.",
	} // Truncated for brevity but follows the pattern.

	seedBlock := "\n*(No seed gotchas for this category — add the first one when you hit a failure)*\n"
	if sb, ok := seeds[s.Category]; ok {
		seedBlock = sb
	}

	return e.RenderTemplate("SKILL_GOTCHAS.md", map[string]string{
		"SKILL_NAME":   s.Name,
		"SEED_BLOCK":   seedBlock,
		"PROJECT_NAME": p.Name,
		"DATE":         time.Now().Format("2006-01-02"),
		"VERSION":      "1.0.0", // Hardcoded for parity
	})
}

// BuildSkillEvalMd generates the SKILL_EVAL.md file
func BuildSkillEvalMd(e *engine.Engine, s *models.Skill, p *models.Project) string {
	return e.RenderTemplate("SKILL_EVAL.md", map[string]string{
		"SKILL_NAME": s.Name,
		"DATE":       time.Now().Format("2006-01-02"),
		"VERSION":    "1.0.0",
	})
}

