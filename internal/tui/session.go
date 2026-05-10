package tui

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/xdagee/msingi/internal/models"
)

// SessionLog records the TUI interaction history
type SessionLog struct {
	StartTime time.Time       `json:"start_time"`
	Project   models.Project  `json:"project"`
	Agents    []models.Agent   `json:"agents"`
	Skills    []models.Skill   `json:"skills"`
	Actions   []string        `json:"actions"`
}

func NewSessionLog(p models.Project) *SessionLog {
	return &SessionLog{
		StartTime: time.Now(),
		Project:   p,
		Actions:   []string{"Session started"},
	}
}

func (l *SessionLog) RecordAction(action string) {
	l.Actions = append(l.Actions, fmt.Sprintf("[%s] %s", time.Now().Format("15:04:05"), action))
}

func (l *SessionLog) Save(root string) error {
	// 1. Save as JSON for reproducibility
	recordPath := filepath.Join(root, "memory", "bootstrap-record.json")
	data, err := json.MarshalIndent(l, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(recordPath, data, 0644); err != nil {
		return err
	}

	// 2. Save as Markdown log for human audit
	logPath := filepath.Join(root, "memory", "BOOTSTRAP.md")
	var sb strings.Builder
	sb.WriteString("# Msingi Bootstrap Log\n\n")
	sb.WriteString(fmt.Sprintf("Generated on: %s\n", l.StartTime.Format(time.RFC3339)))
	sb.WriteString(fmt.Sprintf("Project: %s (%s)\n\n", l.Project.Name, l.Project.TypeLabel))
	
	sb.WriteString("## Agents\n")
	for _, a := range l.Agents {
		sb.WriteString(fmt.Sprintf("- %s (%s)\n", a.Name, a.ID))
	}
	
	sb.WriteString("\n## Skills\n")
	for _, s := range l.Skills {
		sb.WriteString(fmt.Sprintf("- %s (%s)\n", s.Name, s.ID))
	}
	
	sb.WriteString("\n## Timeline\n")
	for _, a := range l.Actions {
		sb.WriteString(fmt.Sprintf("- %s\n", a))
	}

	return os.WriteFile(logPath, []byte(sb.String()), 0644)
}
