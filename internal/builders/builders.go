package builders

import (
	"github.com/xdagee/msingi/internal/engine"
)

// BuildPlansMd generates the PLANS.md file
func BuildPlansMd(e *engine.Engine) string {
	return e.RenderTemplate("PLANS.md", map[string]string{})
}

// BuildPlanTemplateMd generates the .plans/template.md file
func BuildPlanTemplateMd(e *engine.Engine) string {
	return e.RenderTemplate("plan_template.md", map[string]string{})
}

// BuildInboxMd generates the INBOX.md file
func BuildInboxMd(e *engine.Engine) string {
	return e.RenderTemplate("INBOX.md", map[string]string{})
}

// BuildQualityMd generates the QUALITY.md file
func BuildQualityMd(e *engine.Engine, projectName string) string {
	if projectName == "" {
		projectName = "Project"
	}
	return e.RenderTemplate("QUALITY.md", map[string]string{
		"PROJECT_NAME":       projectName,
		"PROJECT_TYPE_LABEL": "Web",
		"QUALITY_GATES":      "",
		"ENTROPY_CONTROL":    "",
	})
}

// BuildObservabilityMd generates the OBSERVABILITY.md file
func BuildObservabilityMd(e *engine.Engine, projectName string) string {
	if projectName == "" {
		projectName = "Project"
	}
	return e.RenderTemplate("OBSERVABILITY.md", map[string]string{
		"PROJECT_NAME":        projectName,
		"PROJECT_TYPE_LABEL":  "Web",
		"OBSERVABILITY_FOCUS": "",
	})
}
