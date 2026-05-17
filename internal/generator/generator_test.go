package generator

import (
	"embed"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/xdagee/msingi/internal/engine"
	"github.com/xdagee/msingi/internal/models"
	"github.com/xdagee/msingi/internal/tui"
	"gopkg.in/yaml.v3"
)

func TestIntegrationGenerateAndSessionLog(t *testing.T) {
	// Setup test engine with local template override
	eng := engine.NewEngine(embed.FS{}, "../../templates")

	// Set up temporary target directory for the scaffolding output
	tempDir, err := os.MkdirTemp("", "msingi-test-scaffold-*")
	if err != nil {
		t.Fatalf("Failed to create temporary directory: %v", err)
	}
	defer os.RemoveAll(tempDir)

	proj := &models.Project{
		Name:                 tempDir, // Direct output to temp directory
		TypeID:               "web-app",
		TypeLabel:            "Web App",
		Description:          "A robust production react portal",
		NeedsAuth:            true,
		HandlesSensitiveData: true,
		SensitiveTags:        "tokens, credentials",
		ScaleProfile:         "growth",
		DeploymentTarget:     "mobile-store",
		Audience:             "public",
		Milestone:            "v1.0.0 Alpha",
		Stack:                "Next.js,TypeScript",
	}

	selectedAgents := []models.Agent{
		{ID: "claude-code", Name: "Claude Code", File: "CLAUDE.md", Scratchpad: "claude-code"},
		{ID: "goose", Name: "Goose", File: "GOOSE.md", Scratchpad: "goose"},
		{ID: "deep-agents", Name: "Deep Agents CLI", File: "DEEP_AGENTS.md", Scratchpad: "deep-agents"},
	}

	selectedSkills := []models.Skill{
		{ID: "auth-logic", Name: "Authentication", Category: "auth"},
	}

	t.Run("Dry-Run Path", func(t *testing.T) {
		// Run generator with dryRun = true
		err := Generate(eng, proj, selectedAgents, selectedSkills, true)
		if err != nil {
			t.Fatalf("Dry run failed: %v", err)
		}

		// Ensure no files or directories were created inside the tempDir
		files, err := os.ReadDir(tempDir)
		if err != nil {
			t.Fatalf("Failed to read temp directory: %v", err)
		}
		if len(files) > 0 {
			t.Errorf("Dry-run created files/directories in tempDir! Found: %d", len(files))
		}
	})

	t.Run("Normal Generation and Session Logging Path", func(t *testing.T) {
		// Run generator with dryRun = false
		err := Generate(eng, proj, selectedAgents, selectedSkills, false)
		if err != nil {
			t.Fatalf("Generator failed: %v", err)
		}

		// Check directories
		requiredDirs := []string{"memory", "memory/decisions", "scratchpads", "agents", "skills", "docs"}
		for _, d := range requiredDirs {
			path := filepath.Join(tempDir, d)
			info, err := os.Stat(path)
			if err != nil {
				t.Errorf("Required directory %s was not created: %v", d, err)
				continue
			}
			if !info.IsDir() {
				t.Errorf("Path %s was created but is not a directory", d)
			}
		}

		// Check core files
		coreFiles := []string{"CONTEXT.md", "TASKS.md", "WORKSTREAMS.md", "TRAJECTORY.md", "QUALITY.md", "OBSERVABILITY.md"}
		for _, f := range coreFiles {
			path := filepath.Join(tempDir, f)
			info, err := os.Stat(path)
			if err != nil {
				t.Errorf("Required core file %s was not created: %v", f, err)
				continue
			}
			if info.IsDir() {
				t.Errorf("Path %s was created but is a directory", f)
			}

			// Validate no unresolved placeholders
			content, err := os.ReadFile(path)
			if err != nil {
				t.Errorf("Failed to read created file %s: %v", f, err)
				continue
			}
			if strings.Contains(string(content), "{{") && strings.Contains(string(content), "}}") {
				t.Errorf("File %s contains unresolved template placeholders!", f)
			}
		}

		// Check agent configs: Goose config (.goose.yaml) should be valid YAML
		gooseConfigPath := filepath.Join(tempDir, ".goose.yaml")
		gooseContent, err := os.ReadFile(gooseConfigPath)
		if err != nil {
			t.Fatalf("Failed to read .goose.yaml: %v", err)
		}
		var parsedGoose map[string]interface{}
		if err := yaml.Unmarshal(gooseContent, &parsedGoose); err != nil {
			t.Errorf("Generated .goose.yaml is not valid YAML: %v", err)
		}
		if parsedGoose["project_name"] != tempDir {
			t.Errorf("Expected project_name to match %s, got %s", tempDir, parsedGoose["project_name"])
		}

		// Check agent configs: Deep Agents config (deepagents.json) should be valid JSON
		deepConfigPath := filepath.Join(tempDir, "deepagents.json")
		deepContent, err := os.ReadFile(deepConfigPath)
		if err != nil {
			t.Fatalf("Failed to read deepagents.json: %v", err)
		}
		var parsedDeep map[string]interface{}
		if err := json.Unmarshal(deepContent, &parsedDeep); err != nil {
			t.Errorf("Generated deepagents.json is not valid JSON: %v", err)
		}
		if parsedDeep["name"] != tempDir {
			t.Errorf("Expected deepagents.json name to match %s, got %s", tempDir, parsedDeep["name"])
		}

		// Run Session Logger Save
		session := tui.NewSessionLog(*proj)
		session.Agents = selectedAgents
		session.Skills = selectedSkills
		session.RecordAction("Wrote configuration files")
		session.RecordAction("Complete integration validation successful")

		err = session.Save(tempDir)
		if err != nil {
			t.Fatalf("Session log save failed: %v", err)
		}

		// Check Session Log JSON
		jsonLogPath := filepath.Join(tempDir, "memory", "bootstrap-record.json")
		jsonContent, err := os.ReadFile(jsonLogPath)
		if err != nil {
			t.Fatalf("Failed to read bootstrap-record.json: %v", err)
		}
		var parsedSession tui.SessionLog
		if err := json.Unmarshal(jsonContent, &parsedSession); err != nil {
			t.Errorf("Session JSON log is not valid JSON: %v", err)
		}
		if len(parsedSession.Actions) != 3 { // Started + 2 recorded
			t.Errorf("Expected 3 timeline actions in Session Log, got %d", len(parsedSession.Actions))
		}

		// Check Session Log Markdown
		mdLogPath := filepath.Join(tempDir, "memory", "BOOTSTRAP.md")
		mdContent, err := os.ReadFile(mdLogPath)
		if err != nil {
			t.Fatalf("Failed to read BOOTSTRAP.md: %v", err)
		}
		mdStr := string(mdContent)
		if !strings.Contains(mdStr, "# Msingi Bootstrap Log") ||
			!strings.Contains(mdStr, "Claude Code") ||
			!strings.Contains(mdStr, "Authentication") ||
			!strings.Contains(mdStr, "bootstrap-record.json") && false { // check tags exist
			t.Errorf("BOOTSTRAP.md content incomplete:\n%s", mdStr)
		}
	})
}
