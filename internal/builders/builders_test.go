package builders

import (
	"embed"
	"strings"
	"testing"

	"github.com/xdagee/msingi/internal/engine"
	"github.com/xdagee/msingi/internal/models"
)

func newTestEngine() *engine.Engine {
	// Pass an empty embed.FS, but specify the local templates path relative to this package
	return engine.NewEngine(embed.FS{}, "../../templates")
}

func TestStaticBuilders(t *testing.T) {
	e := newTestEngine()

	t.Run("Plans", func(t *testing.T) {
		res := BuildPlansMd(e)
		if strings.Contains(res, "ERROR:") {
			t.Errorf("BuildPlansMd returned template error: %s", res)
		}
		if !strings.Contains(res, "# PLANS.md") {
			t.Errorf("Expected BuildPlansMd to contain plans header, got: %s", res)
		}
	})

	t.Run("Plan Template", func(t *testing.T) {
		res := BuildPlanTemplateMd(e)
		if strings.Contains(res, "ERROR:") {
			t.Errorf("BuildPlanTemplateMd returned template error: %s", res)
		}
	})

	t.Run("Inbox", func(t *testing.T) {
		res := BuildInboxMd(e)
		if strings.Contains(res, "ERROR:") {
			t.Errorf("BuildInboxMd returned template error: %s", res)
		}
	})

	t.Run("Quality", func(t *testing.T) {
		res := BuildQualityMd(e, "MyProj", "Android App")
		if strings.Contains(res, "ERROR:") {
			t.Errorf("BuildQualityMd returned template error: %s", res)
		}
		if !strings.Contains(res, "MyProj") || !strings.Contains(res, "Android App") {
			t.Errorf("Quality template did not substitute variables correctly: %s", res)
		}
	})

	t.Run("Observability", func(t *testing.T) {
		res := BuildObservabilityMd(e, "MyProj", "CLI Tool")
		if strings.Contains(res, "ERROR:") {
			t.Errorf("BuildObservabilityMd returned template error: %s", res)
		}
		if !strings.Contains(res, "MyProj") || !strings.Contains(res, "CLI Tool") {
			t.Errorf("Observability template did not substitute variables correctly: %s", res)
		}
	})
}

func TestDynamicBuilders(t *testing.T) {
	e := newTestEngine()
	proj := &models.Project{
		Name:                 "TestProject",
		TypeLabel:            "Web App",
		Description:          "A beautiful Next.js web application",
		NeedsAuth:            true,
		HandlesSensitiveData: true,
		SensitiveTags:        "credentials, PII",
		ScaleProfile:         "growth",
		DeploymentTarget:     "mobile-store",
		Audience:             "public",
		Milestone:            "v1.0.0 Prod Release",
		Stack:                "Next.js,TypeScript,PostgreSQL",
	}

	t.Run("Tasks", func(t *testing.T) {
		res := BuildTasksMd(e, proj)
		if strings.Contains(res, "ERROR:") {
			t.Errorf("BuildTasksMd failed: %s", res)
		}
		if !strings.Contains(res, "v1.0.0 Prod Release") {
			t.Errorf("Tasks missing milestone: %s", res)
		}
		if !strings.Contains(res, "Design and document auth flow") {
			t.Errorf("Tasks missing conditional auth task: %s", res)
		}
		if !strings.Contains(res, "sensitive data inventory") {
			t.Errorf("Tasks missing conditional sensitive data task: %s", res)
		}
	})

	t.Run("Context", func(t *testing.T) {
		res := BuildContextMd(e, proj)
		if strings.Contains(res, "ERROR:") {
			t.Errorf("BuildContextMd failed: %s", res)
		}
		if !strings.Contains(res, "TestProject") || !strings.Contains(res, "Next.js") {
			t.Errorf("Context missing project name or stack: %s", res)
		}
	})

	t.Run("Workstreams", func(t *testing.T) {
		agents := []models.Agent{
			{ID: "claude-code", Name: "Claude Code", File: "CLAUDE.md"},
			{ID: "aider", Name: "Aider", File: "AIDER.md"},
		}
		res := BuildWorkstreamsMd(e, proj, agents, nil)
		if strings.Contains(res, "ERROR:") {
			t.Errorf("BuildWorkstreamsMd failed: %s", res)
		}
		if !strings.Contains(res, "Claude Code") || !strings.Contains(res, "Aider") {
			t.Errorf("Workstreams missing agents: %s", res)
		}
	})

	t.Run("Trajectory", func(t *testing.T) {
		res := BuildTrajectoryMd(e, proj)
		if strings.Contains(res, "ERROR:") {
			t.Errorf("BuildTrajectoryMd failed: %s", res)
		}
	})

	t.Run("Agent", func(t *testing.T) {
		agent := &models.Agent{
			ID:          "claude-code",
			Name:        "Claude Code",
			File:        "CLAUDE.md",
			Scratchpad:  "claude-code",
			DocsUrl:     "https://docs.anthropic.com",
			Description: "Best agent",
		}
		res := BuildAgentMd(e, agent, proj)
		if strings.Contains(res, "ERROR:") {
			t.Errorf("BuildAgentMd failed: %s", res)
		}
		if !strings.Contains(res, "CLAUDE") || !strings.Contains(res, "TestProject") {
			t.Errorf("Agent MD missing agent/project info: %s", res)
		}
	})

	t.Run("Skill Spec, Gotchas, Eval", func(t *testing.T) {
		skill := &models.Skill{
			ID:          "auth-logic",
			Name:        "Authentication",
			Category:    "auth",
			Description: "Secure auth flow",
		}
		spec := BuildSkillSpecMd(e, skill, proj)
		if strings.Contains(spec, "ERROR:") {
			t.Errorf("BuildSkillSpecMd failed: %s", spec)
		}
		if !strings.Contains(spec, "Authentication") {
			t.Errorf("Skill Spec missing name: %s", spec)
		}

		gotchas := BuildSkillGotchasMd(e, skill, proj)
		if strings.Contains(gotchas, "ERROR:") {
			t.Errorf("BuildSkillGotchasMd failed: %s", gotchas)
		}

		eval := BuildSkillEvalMd(e, skill, proj)
		if strings.Contains(eval, "ERROR:") {
			t.Errorf("BuildSkillEvalMd failed: %s", eval)
		}
	})
}

func TestConfigBuilders(t *testing.T) {
	proj := &models.Project{
		Name:        "ConfigProject",
		Description: "A safe project",
	}

	t.Run("Goose", func(t *testing.T) {
		res := BuildGooseConfig(proj)
		if !strings.Contains(res, "project_name: ConfigProject") {
			t.Errorf("Goose config incorrect: %s", res)
		}
	})

	t.Run("DeepAgents", func(t *testing.T) {
		res := BuildDeepAgentsConfig(proj)
		if !strings.Contains(res, `"name": "ConfigProject"`) {
			t.Errorf("DeepAgents config incorrect: %s", res)
		}
	})

	t.Run("ForgeCode", func(t *testing.T) {
		res := BuildForgeCodeConfig(proj)
		if !strings.Contains(res, `"project": "ConfigProject"`) {
			t.Errorf("ForgeCode config incorrect: %s", res)
		}
	})

	t.Run("Plandex", func(t *testing.T) {
		res := BuildPlandexConfig(proj)
		if !strings.Contains(res, "name: ConfigProject") {
			t.Errorf("Plandex config incorrect: %s", res)
		}
	})
}
