package tui

import (
	"fmt"
	tea "github.com/charmbracelet/bubbletea"
)

func (m MainModel) updateStep(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "p":
			m.ShowPreview = !m.ShowPreview
			m.Session.RecordAction("Toggled preview: " + map[bool]string{true: "ON", false: "OFF"}[m.ShowPreview])
			return m, nil
		}
	}

	var cmd tea.Cmd

	switch m.Step {
	case StepMode:
		return m.updateMode(msg)
	case StepType:
		return m.updateType(msg)
	case StepDetails:
		return m.updateDetails(msg)
	case StepIntake:
		return m.updateIntake(msg)
	case StepAgents:
		return m.updateAgents(msg)
	case StepSkills:
		return m.updateSkills(msg)
	case StepReview:
		return m.updateReview(msg)
	default:
		return m, cmd
	}
}

func (m MainModel) updateMode(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.Cursor > 0 {
				m.Cursor--
			}
		case "down", "j":
			if m.Cursor < 1 {
				m.Cursor++
			}
		case "enter":
			m.SelectedModeIdx = m.Cursor
			m.Advanced = m.SelectedModeIdx == 1
			m.Step = StepType
			m.Cursor = 0
			m.Session.RecordAction("Selected mode: " + map[bool]string{true: "Advanced", false: "Standard"}[m.Advanced])
		}
	}
	return m, nil
}

func (m MainModel) updateType(msg tea.Msg) (tea.Model, tea.Cmd) {
	types := []string{"Web App", "API Service", "CLI Tool", "Android App", "Desktop (Windows)"}
	
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.Cursor > 0 {
				m.Cursor--
			}
		case "down", "j":
			if m.Cursor < len(types)-1 {
				m.Cursor++
			}
		case "enter":
			m.SelectedTypeIdx = m.Cursor
			m.Project.TypeLabel = types[m.SelectedTypeIdx]
			m.Step = StepDetails
			m.Cursor = 0
			m.Session.RecordAction("Selected type: " + m.Project.TypeLabel)
		}
	}
	return m, nil
}

func (m MainModel) updateDetails(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	m.TextInput, cmd = m.TextInput.Update(msg)
	
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			m.Project.Name = m.TextInput.Value()
			m.Session.RecordAction("Entered project name: " + m.Project.Name)
			if m.Advanced {
				m.Step = StepIntake
				m.IntakeStep = 0
			} else {
				m.Step = StepAgents
			}
			m.Cursor = 0
		}
	}
	return m, cmd
}

func (m MainModel) updateIntake(msg tea.Msg) (tea.Model, tea.Cmd) {
	questions := []string{"Audience", "Auth", "Data", "Deploy", "Scale"}
	options := [][]string{
		{"Public", "Internal", "B2B", "Mobile"},
		{"Yes", "No"},
		{"None", "PII/PHI", "Financial", "System Secrets"},
		{"Cloud", "On-premises", "Edge", "Mobile store"},
		{"Personal", "Small team", "Growth", "Enterprise"},
	}

	currentOptions := options[m.IntakeStep]

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.Cursor > 0 {
				m.Cursor--
			}
		case "down", "j":
			if m.Cursor < len(currentOptions)-1 {
				m.Cursor++
			}
		case "enter":
			// Record selection
			val := currentOptions[m.Cursor]
			m.Session.RecordAction(fmt.Sprintf("Intake %s: %s", questions[m.IntakeStep], val))
			switch questions[m.IntakeStep] {
			case "Audience": m.Project.AudienceLabel = val
			case "Auth": m.Project.NeedsAuth = val == "Yes"
			case "Data": m.Project.SensitiveTags = val
			case "Deploy": m.Project.DeployLabel = val
			case "Scale": m.Project.ScaleLabel = val
			}

			if m.IntakeStep < len(questions)-1 {
				m.IntakeStep++
				m.Cursor = 0
			} else {
				m.Step = StepAgents
				m.Cursor = 0
			}
		}
	}
	return m, nil
}

func (m MainModel) updateAgents(msg tea.Msg) (tea.Model, tea.Cmd) {
	pageSize := 10
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.Cursor > 0 {
				m.Cursor--
				if m.Cursor < m.ListOffset {
					m.ListOffset--
				}
			}
		case "down", "j":
			if m.Cursor < len(m.AllAgents)-1 {
				m.Cursor++
				if m.Cursor >= m.ListOffset+pageSize {
					m.ListOffset++
				}
			}
		case " ": // Toggle selection
			agent := m.AllAgents[m.Cursor]
			found := -1
			for i, a := range m.SelectedAgents {
				if a.ID == agent.ID {
					found = i
					break
				}
			}
			if found >= 0 {
				m.SelectedAgents = append(m.SelectedAgents[:found], m.SelectedAgents[found+1:]...)
				m.Session.RecordAction("Deselected agent: " + agent.Name)
			} else {
				m.SelectedAgents = append(m.SelectedAgents, agent)
				m.Session.RecordAction("Selected agent: " + agent.Name)
			}
		case "enter":
			m.Step = StepSkills
			m.Cursor = 0
			m.ListOffset = 0
			// Run skill inference
			m.SelectedSkills = InferSkills(m.Project.Name+" "+m.Project.Description, m.Project.TypeLabel, m.AllSkills)
			m.Session.RecordAction(fmt.Sprintf("Inferred %d skills", len(m.SelectedSkills)))
		}
	}
	return m, nil
}

func (m MainModel) updateSkills(msg tea.Msg) (tea.Model, tea.Cmd) {
	pageSize := 10
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.Cursor > 0 {
				m.Cursor--
				if m.Cursor < m.ListOffset {
					m.ListOffset--
				}
			}
		case "down", "j":
			if m.Cursor < len(m.SelectedSkills)-1 {
				m.Cursor++
				if m.Cursor >= m.ListOffset+pageSize {
					m.ListOffset++
				}
			}
		case "enter":
			m.Step = StepReview
			m.Cursor = 0
			m.ListOffset = 0
			m.Session.RecordAction("Confirmed skills")
		}
	}
	return m, nil
}

func (m MainModel) updateReview(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			if m.Confirming {
				m.Session.RecordAction("Confirmed final scaffolding")
				return m, tea.Quit
			}
			m.Confirming = true
			m.Session.RecordAction("Entering confirmation state")
		case "esc", "backspace":
			if m.Confirming {
				m.Confirming = false
				m.Session.RecordAction("Cancelled confirmation state")
			}
		}
	}
	return m, nil
}
