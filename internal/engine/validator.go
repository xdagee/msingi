package engine

import (
	"embed"
	"fmt"
	"io/fs"
	"strings"
)

// RequiredPlaceholders maps template filenames to their mandatory tokens
var RequiredPlaceholders = map[string][]string{
	"templates/AGENT.md":     {"{{AGENT_NAME}}", "{{PROJECT_NAME}}", "{{STACK_LINES}}", "{{AGENT_ID}}"},
	"templates/CONTEXT.md":   {"{{PROJECT_NAME}}", "{{STACK_LINES}}"},
	"templates/SKILL.md":     {"{{SKILL_NAME}}", "{{TRIGGER}}", "{{SKILL_ID}}", "{{QS}}"},
	"templates/TASKS.md":     {"{{MILESTONE}}", "{{INTAKE_TASKS}}"},
	"templates/WORKSTREAMS.md": {"{{PROJECT_NAME}}", "{{WORKSTREAM_DEFINITIONS}}"},
}

// ValidateTemplates checks all embedded templates for required sections and placeholders
func ValidateTemplates(fsys embed.FS, verbose bool) error {
	return fs.WalkDir(fsys, "templates", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(path, ".md") {
			return nil
		}

		content, err := fsys.ReadFile(path)
		if err != nil {
			return fmt.Errorf("failed to read template %s: %v", path, err)
		}

		if verbose {
			fmt.Printf("Validating template: %s\n", path)
		}

		// Check required placeholders
		if required, ok := RequiredPlaceholders[path]; ok {
			for _, p := range required {
				if !strings.Contains(string(content), p) {
					msg := fmt.Sprintf("Template %s is missing required placeholder: %s", path, p)
					if verbose {
						fmt.Printf("WARNING: %s\n", msg)
					} else {
						// In non-verbose mode, we still want to know if critical templates are broken
						return fmt.Errorf("%s", msg)
					}
				}
			}
		}

		return nil
	})
}
