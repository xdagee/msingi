package tui

import (
	tea "github.com/charmbracelet/bubbletea"
	"github.com/xdagee/msingi/internal/models"
)

type TUIResult struct {
	Project        *models.Project
	SelectedAgents []models.Agent
	SelectedSkills []models.Skill
	Session        *SessionLog
}

// Run starts the interactive wizard and returns the final project configuration
func Run(agents []models.Agent, skills []models.Skill) (*TUIResult, error) {
	p := tea.NewProgram(NewModel(agents, skills), tea.WithAltScreen())
	
	m, err := p.Run()
	if err != nil {
		return nil, err
	}
	
	finalModel := m.(MainModel)
	if finalModel.Quitting {
		return nil, nil // User cancelled
	}
	
	// Convert InferredSkill back to models.Skill for the generator
	var selectedSkills []models.Skill
	for _, s := range finalModel.SelectedSkills {
		selectedSkills = append(selectedSkills, s.Skill)
	}
	
	return &TUIResult{
		Project:        &finalModel.Project,
		SelectedAgents: finalModel.SelectedAgents,
		SelectedSkills: selectedSkills,
		Session:        finalModel.Session,
	}, nil
}
