package generator

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/xdagee/msingi/internal/builders"
	"github.com/xdagee/msingi/internal/engine"
	"github.com/xdagee/msingi/internal/models"
)

func Generate(eng *engine.Engine, p *models.Project, agents []models.Agent, skills []models.Skill, dryRun bool) error {
	if dryRun {
		fmt.Println("Msingi Dry Run: Skipping all disk writes")
	}
	root := p.Name
	if root == "" {
		root = "scaffold"
	}

	// Create core directories
	dirs := []string{
		"memory",
		"memory/decisions",
		"scratchpads",
		"agents",
		"skills",
		"docs",
	}

	for _, d := range dirs {
		path := filepath.Join(root, d)
		if dryRun {
			fmt.Printf("[DRY-RUN] Would create directory: %s\n", path)
			continue
		}
		if err := os.MkdirAll(path, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %v", path, err)
		}
	}

	// Core context files
	files := map[string]string{
		"CONTEXT.md":     builders.BuildContextMd(eng, p),
		"TASKS.md":       builders.BuildTasksMd(eng, p),
		"WORKSTREAMS.md": builders.BuildWorkstreamsMd(eng, p, agents, skills),
		"TRAJECTORY.md":  builders.BuildTrajectoryMd(eng, p),
		"QUALITY.md":     builders.BuildQualityMd(eng, p.Name, p.TypeLabel),
		"OBSERVABILITY.md": builders.BuildObservabilityMd(eng, p.Name, p.TypeLabel),
	}

	for relPath, content := range files {
		fullPath := filepath.Join(root, relPath)
		if dryRun {
			fmt.Printf("[DRY-RUN] Would write file: %s (%d bytes)\n", fullPath, len(content))
			continue
		}
		if err := writeFile(fullPath, content); err != nil {
			return err
		}
	}

	// Agent files
	for _, a := range agents {
		content := builders.BuildAgentMd(eng, &a, p)
		agentPath := filepath.Join(root, "agents", a.File)
		if dryRun {
			fmt.Printf("[DRY-RUN] Would write file: %s\n", agentPath)
		} else {
			if err := writeFile(agentPath, content); err != nil {
				return err
			}
		}
		
		// Create agent scratchpad
		agentDir := strings.ToLower(strings.TrimSuffix(a.File, ".md"))
		scratchDir := filepath.Join(root, "scratchpads", agentDir)
		if dryRun {
			fmt.Printf("[DRY-RUN] Would create directory: %s\n", scratchDir)
			fmt.Printf("[DRY-RUN] Would write file: %s/SESSION.md\n", scratchDir)
		} else {
			if err := os.MkdirAll(scratchDir, 0755); err != nil {
				return err
			}
			if err := writeFile(filepath.Join(scratchDir, "SESSION.md"), "# Session Log"); err != nil {
				return err
			}
		}

		// Agent-specific config files
		if !dryRun {
			var err error
			switch a.ID {
			case "goose":
				err = writeFile(filepath.Join(root, ".goose.yaml"), builders.BuildGooseConfig(p))
			case "deep-agents":
				err = writeFile(filepath.Join(root, "deepagents.json"), builders.BuildDeepAgentsConfig(p))
			case "forgecode":
				err = writeFile(filepath.Join(root, "forgecode.json"), builders.BuildForgeCodeConfig(p))
			case "plandex":
				err = writeFile(filepath.Join(root, "plandex.yaml"), builders.BuildPlandexConfig(p))
			}
			if err != nil {
				return err
			}
		}
	}

	// Skill files
	for _, s := range skills {
		skillDir := filepath.Join(root, "skills", s.ID)
		if dryRun {
			fmt.Printf("[DRY-RUN] Would create directory: %s\n", skillDir)
			fmt.Printf("[DRY-RUN] Would write skill files for: %s\n", s.ID)
		} else {
			if err := os.MkdirAll(skillDir, 0755); err != nil {
				return err
			}
			if err := writeFile(filepath.Join(skillDir, "SKILL.md"), builders.BuildSkillSpecMd(eng, &s, p)); err != nil {
				return err
			}
			if err := writeFile(filepath.Join(skillDir, "gotchas.md"), builders.BuildSkillGotchasMd(eng, &s, p)); err != nil {
				return err
			}
			if err := writeFile(filepath.Join(skillDir, "EVAL.md"), builders.BuildSkillEvalMd(eng, &s, p)); err != nil {
				return err
			}
		}
	}

	return nil
}

func writeFile(path string, content string) error {
	return os.WriteFile(path, []byte(content), 0644)
}
