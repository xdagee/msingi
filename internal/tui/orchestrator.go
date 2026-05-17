package tui

import (
	"fmt"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/xdagee/msingi/internal/engine"
)

func (m MainModel) updateStep(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch m.Step {
	case StepWelcome:
		return m.updateWelcome(msg)
	case StepDescribe:
		return m.updateDescribe(msg)
	case StepSummary:
		return m.updateSummary(msg)
	case StepClarify:
		return m.updateClarify(msg)
	case StepGenerate:
		return m.updateGenerate(msg)
	case StepDone:
		return m.updateDone(msg)
	default:
		return m, nil
	}
}

func (m MainModel) updateWelcome(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			m.Step = StepDescribe
			return m, nil
		}
	}
	return m, nil
}

func (m MainModel) updateDescribe(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	
	if m.Project.Name == "" {
		m.TextInput, cmd = m.TextInput.Update(msg)
	} else {
		m.TextArea, cmd = m.TextArea.Update(msg)
	}
	
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			if m.Project.Name == "" {
				val := m.TextInput.Value()
				if val == "" {
					return m, nil
				}
				m.Project.Name = val
				m.TextArea.Focus()
				return m, nil
			}
			
			// If TextArea is focused, Enter is a newline unless Ctrl+Enter or something?
			// Bubble Tea TextArea handles Enter as newline.
			// Let's use Ctrl+Enter or Tab to proceed? 
			// User said "Accept multiline input". 
			// I'll use Ctrl+Enter to proceed.
		case "ctrl+d", "ctrl+enter":
			if m.Project.Name != "" && m.TextArea.Value() != "" {
				m.Project.Description = m.TextArea.Value()
				
				// Run Inference
				inf, _ := engine.InferFeatures(m.Project.Description)
				m.Project.TypeID = inf.TypeID
				m.Project.TypeLabel = inf.TypeLabel
				m.Project.InferredGoals = inf.Goals
				m.Project.InferredFeatures = inf.Features
				m.Project.InferenceConfidence = inf.Confidence
				m.FieldConfidence = inf.FieldConfidence
				
				// Map Features to Skills
				mappedSkills := engine.MapFeaturesToSkills(inf.Features, m.AllSkills)
				
				// Run detailed skill inference (triggers)
				m.InferredSkills = engine.InferSkills(m.Project.Description, inf.TypeID, m.AllSkills)
				
				// Suggest Stack
				m.Project.Stack = engine.SuggestTechStack(&m.Project, mappedSkills)
				
				// Infer Agents
				m.SelectedAgents = engine.InferAgents(inf.Features, m.AllAgents)
				
				m.Session.RecordAction(fmt.Sprintf("Inferred Type: %s, Confidence: %.2f", inf.TypeLabel, inf.Confidence))
				
				m.Step = StepSummary
				m.Cursor = 0
			}
		}
	}
	return m, cmd
}

func (m MainModel) updateSummary(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.Cursor > 0 {
				m.Cursor--
			}
		case "down", "j":
			if m.Cursor < 2 {
				m.Cursor++
			}
		case "enter":
			switch m.Cursor {
			case 0: // Accept
				// Find first low-confidence field
				m.IntakeStep = 0
				m.nextClarification()
				if m.Step == StepSummary { // No low-confidence fields found
					m.Step = StepGenerate
					return m, m.Spinner.Tick
				}
			case 1: // Edit Description
				m.Step = StepDescribe
				m.TextArea.Focus()
			case 2: // Clarify All
				m.Step = StepClarify
				m.IntakeStep = 0
			}
			m.Cursor = 0
		}
	}
	return m, nil
}

func (m *MainModel) nextClarification() {
	questions := []string{"Audience", "Auth", "Data", "Deploy", "Scale"}
	
	for i := m.IntakeStep; i < len(questions); i++ {
		conf := m.FieldConfidence[questions[i]]
		if conf < 0.6 { // Low confidence threshold
			m.IntakeStep = i
			m.Step = StepClarify
			return
		}
	}
	
	// If no low confidence fields left
	m.Step = StepSummary // Go back to summary or proceed to Generate? 
	// The plan says "Clarify Phase -> Generate Phase"
}

func (m MainModel) updateClarify(msg tea.Msg) (tea.Model, tea.Cmd) {
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
			val := currentOptions[m.Cursor]
			m.Session.RecordAction(fmt.Sprintf("Intake %s: %s", questions[m.IntakeStep], val))
			switch questions[m.IntakeStep] {
			case "Audience": m.Project.AudienceLabel = val
			case "Auth": m.Project.NeedsAuth = val == "Yes"
			case "Data": m.Project.SensitiveTags = val
			case "Deploy": m.Project.DeployLabel = val
			case "Scale": m.Project.ScaleLabel = val
			}

			m.IntakeStep++
			m.nextClarification()
			if m.Step == StepSummary { // Finished clarifications
				m.Step = StepGenerate
				return m, m.Spinner.Tick
			}
			m.Cursor = 0
		case "esc":
			m.Step = StepSummary
		}
	}
	return m, nil
}

func (m MainModel) updateGenerate(msg tea.Msg) (tea.Model, tea.Cmd) {
	if !m.Generating {
		m.Generating = true
		return m, tea.Tick(time.Second*2, func(t time.Time) tea.Msg {
			return "done"
		})
	}
	
	switch msg.(type) {
	case string:
		if msg == "done" {
			m.Step = StepDone
			m.Generating = false
		}
	}
	return m, nil
}

func (m MainModel) updateDone(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		}
	}
	return m, nil
}
