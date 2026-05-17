package tui

import (
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textarea"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/xdagee/msingi/internal/engine"
	"github.com/xdagee/msingi/internal/models"
)

type Step int

const (
	StepWelcome Step = iota
	StepDescribe
	StepSummary
	StepClarify
	StepGenerate
	StepDone
)

// MainModel is the root model for the Msingi TUI
type MainModel struct {
	Step      Step
	Project   models.Project
	AllAgents []models.Agent
	AllSkills []models.Skill
	
	// Inference Results
	InferredSkills  []engine.InferredSkill
	SelectedAgents  []models.Agent
	FieldConfidence map[string]float64
	
	// Input components
	TextInput       textinput.Model
	TextArea        textarea.Model
	Spinner         spinner.Model
	
	// Selection State
	Cursor          int
	IntakeStep      int
	ListOffset      int
	
	// UI State
	Width       int
	Height      int
	ShowPreview bool
	Confirming  bool
	Quitting    bool
	Generating  bool
	
	// Logging
	Session *SessionLog
}

func NewModel(agents []models.Agent, skills []models.Skill) MainModel {
	ti := textinput.New()
	ti.Placeholder = "Project Name (e.g. Msingi)"
	ti.Focus()

	ta := textarea.New()
	ta.Placeholder = "Describe your project features, goals, and audience in detail..."
	ta.SetWidth(60)
	ta.SetHeight(5)
	
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))
	
	return MainModel{
		Step:            StepWelcome,
		AllAgents:       agents,
		AllSkills:       skills,
		TextInput:       ti,
		TextArea:        ta,
		Spinner:         s,
		Project:         models.Project{},
		FieldConfidence: make(map[string]float64),
		Session:         NewSessionLog(models.Project{}),
	}
}

func (m MainModel) Init() tea.Cmd {
	return tea.Batch(textinput.Blink, textarea.Blink)
}

func (m MainModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			m.Quitting = true
			return m, tea.Quit
		case "q":
			if m.Step == StepWelcome || m.Step == StepDone {
				m.Quitting = true
				return m, tea.Quit
			}
		}
	case tea.WindowSizeMsg:
		m.Width = msg.Width
		m.Height = msg.Height
	case spinner.TickMsg:
		var cmd tea.Cmd
		m.Spinner, cmd = m.Spinner.Update(msg)
		return m, cmd
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
