package tui

import (
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/xdagee/msingi/internal/models"
)

type Step int

const (
	StepMode Step = iota
	StepType
	StepDetails
	StepIntake
	StepAgents
	StepSkills
	StepReview
	StepDone
)

// MainModel is the root model for the Msingi TUI
type MainModel struct {
	Step      Step
	Advanced  bool
	Project   models.Project
	AllAgents []models.Agent
	AllSkills []models.Skill
	
	// Selections
	SelectedAgents []models.Agent
	SelectedSkills []InferredSkill
	
	// Input components
	TextInput textinput.Model
	
	// Selection State
	Cursor          int
	SelectedModeIdx int
	SelectedTypeIdx int
	IntakeStep      int
	ListOffset      int
	
	// UI State
	Width       int
	Height      int
	ShowPreview bool
	Confirming  bool
	Quitting    bool
	
	// Logging
	Session *SessionLog
}

func NewModel(agents []models.Agent, skills []models.Skill) MainModel {
	ti := textinput.New()
	ti.Placeholder = "Project Name"
	ti.Focus()
	
	return MainModel{
		Step:      StepMode,
		AllAgents: agents,
		AllSkills: skills,
		TextInput: ti,
		Project:   models.Project{TypeLabel: "Web"},
		Session:   NewSessionLog(models.Project{}),
	}
}

func (m MainModel) Init() tea.Cmd {
	return textinput.Blink
}

func (m MainModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.Quitting = true
			return m, tea.Quit
		}
	case tea.WindowSizeMsg:
		m.Width = msg.Width
		m.Height = msg.Height
	}

	// Delegate to step-specific update logic (to be implemented)
	return m.updateStep(msg)
}

func (m MainModel) View() string {
	if m.Quitting {
		return "Exiting Msingi...\n"
	}
	
	// Layout: Sidebar (left) + Content (right)
	sidebar := m.renderSidebar()
	content := m.renderContent()
	
	return lipgloss.JoinHorizontal(lipgloss.Top, sidebar, content)
}
