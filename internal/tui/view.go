package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

func (m MainModel) renderSidebar() string {
	steps := []string{"Mode", "Type", "Details", "Intake", "Agents", "Skills", "Review"}
	
	var sb strings.Builder
	sb.WriteString(StyleStepActive.Render(BrandLogo))
	sb.WriteString("\n\n")
	
	for i, label := range steps {
		stepIdx := Step(i)
		prefix := IconDot
		style := StyleStepDim
		
		if stepIdx < m.Step {
			prefix = IconDone
			style = StyleStepDone
		} else if stepIdx == m.Step {
			prefix = IconActive
			style = StyleStepActive
		}
		
		sb.WriteString(style.Render(fmt.Sprintf("  %s  %s", prefix, label)))
		sb.WriteString("\n")
	}
	
	// Step Progress
	sb.WriteString("\n\n")
	progress := fmt.Sprintf("  Step %d/7", int(m.Step)+1)
	sb.WriteString(StyleHint.Render(progress))
	
	// Summary at bottom of sidebar
	if m.Step > StepType {
		sb.WriteString("\n\n")
		sb.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("#24242E")).Render("  " + strings.Repeat("-", 20)))
		sb.WriteString("\n")
		name := m.Project.Name
		if name == "" {
			name = "Unnamed Project"
		}
		sb.WriteString(StyleHint.Render(fmt.Sprintf("  %s\n  %s", name, m.Project.TypeLabel)))
	}
	
	return StyleSidebar.Render(sb.String())
}

func (m MainModel) renderContent() string {
	var sb strings.Builder
	
	// Calculate width for content
	contentWidth := m.Width - 26 // Sidebar is 26
	if m.ShowPreview {
		contentWidth -= 32 // Preview is 32 (30 + border/padding)
	}
	if contentWidth < 40 {
		contentWidth = 40
	}
	
	contentStyle := StyleContent.Copy().Width(contentWidth)

	// Header
	sb.WriteString(StyleHeader.Render("Msingi Setup"))
	sb.WriteString("\n\n")
	
	switch m.Step {
	case StepMode:
		sb.WriteString(m.viewMode())
	case StepType:
		sb.WriteString(m.viewType())
	case StepDetails:
		sb.WriteString(m.viewDetails())
	case StepIntake:
		sb.WriteString(m.viewIntake())
	case StepAgents:
		sb.WriteString(m.viewAgents())
	case StepSkills:
		sb.WriteString(m.viewSkills())
	case StepReview:
		sb.WriteString(m.viewReview())
	}
	
	content := contentStyle.Render(sb.String())
	
	if m.ShowPreview {
		preview := m.renderPreview()
		return lipgloss.JoinHorizontal(lipgloss.Top, content, preview)
	}
	
	return content
}

func (m MainModel) renderPreview() string {
	var sb strings.Builder
	sb.WriteString(StyleTitle.Render("Context Preview"))
	sb.WriteString("\n")
	sb.WriteString(StyleHint.Render("Estimated token pressure") + "\n\n")
	
	// Simple token estimation
	tokens := 1200 // baseline
	tokens += len(m.SelectedAgents) * 800
	tokens += len(m.SelectedSkills) * 450
	
	pressure := "Low"
	color := ColorSuccess
	if tokens > 8000 {
		pressure = "Moderate"
		color = ColorWarning
	}
	if tokens > 20000 {
		pressure = "High"
		color = ColorError
	}
	
	sb.WriteString(fmt.Sprintf("Tokens:   %s\n", lipgloss.NewStyle().Foreground(color).Render(fmt.Sprintf("%d", tokens))))
	sb.WriteString(fmt.Sprintf("Pressure: %s\n", lipgloss.NewStyle().Foreground(color).Render(pressure)))
	
	sb.WriteString("\n" + StyleHint.Render("Msingi optimizes context by gardening redundant history."))
	
	return lipgloss.NewStyle().
		Width(30).
		Padding(1, 2).
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(lipgloss.Color("#24242E")).
		Render(sb.String())
}

func (m MainModel) viewMode() string {
	modes := []string{"Standard (recommended)", "Advanced (full control)"}
	var sb strings.Builder
	sb.WriteString("How would you like to build your project?\n\n")
	
	for i, mode := range modes {
		cursor := "  "
		style := StyleUnselected
		if m.Cursor == i {
			cursor = StyleSelected.Render("> ")
			style = StyleSelected
		}
		sb.WriteString(fmt.Sprintf("%s%s\n", cursor, style.Render(mode)))
	}
	
	sb.WriteString("\n" + StyleHint.Render("Standard handles the basics. Advanced asks 5 extra questions about scale, auth, and data."))
	return sb.String()
}

func (m MainModel) viewType() string {
	types := []string{"Web App", "API Service", "CLI Tool", "Android App", "Desktop (Windows)"}
	var sb strings.Builder
	sb.WriteString("What are you building today?\n\n")
	
	for i, t := range types {
		cursor := "  "
		style := StyleUnselected
		if m.Cursor == i {
			cursor = StyleSelected.Render("> ")
			style = StyleSelected
		}
		sb.WriteString(fmt.Sprintf("%s%s\n", cursor, style.Render(t)))
	}
	
	return sb.String()
}

func (m MainModel) viewDetails() string {
	var sb strings.Builder
	sb.WriteString("Project Details\n\n")
	sb.WriteString(StyleUnselected.Render("Project Name"))
	sb.WriteString("\n")
	sb.WriteString(m.TextInput.View())
	sb.WriteString("\n\n" + StyleHint.Render("Press Enter to continue"))
	return sb.String()
}

func (m MainModel) viewIntake() string {
	questions := []string{"Audience", "Auth", "Data", "Deploy", "Scale"}
	subs := []string{
		"Who is this system for?",
		"Does it require authentication?",
		"What kind of data does it handle?",
		"Where will it be deployed?",
		"What is the expected usage scale?",
	}
	options := [][]string{
		{"Public", "Internal", "B2B", "Mobile"},
		{"Yes", "No"},
		{"None", "PII/PHI", "Financial", "System Secrets"},
		{"Cloud", "On-premises", "Edge", "Mobile store"},
		{"Personal", "Small team", "Growth", "Enterprise"},
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("%s\n", questions[m.IntakeStep]))
	sb.WriteString(StyleHint.Render(subs[m.IntakeStep]) + "\n\n")

	for i, opt := range options[m.IntakeStep] {
		cursor := "  "
		style := StyleUnselected
		if m.Cursor == i {
			cursor = StyleSelected.Render("> ")
			style = StyleSelected
		}
		sb.WriteString(fmt.Sprintf("%s%s\n", cursor, style.Render(opt)))
	}

	return sb.String()
}

func (m MainModel) viewAgents() string {
	pageSize := 10
	var sb strings.Builder
	sb.WriteString("Select Agents\n")
	sb.WriteString(StyleHint.Render("Choose the AI agents that will work on this project") + "\n\n")

	for i := m.ListOffset; i < m.ListOffset+pageSize && i < len(m.AllAgents); i++ {
		a := m.AllAgents[i]
		cursor := "  "
		checked := "[ ]"
		style := StyleUnselected
		
		if m.Cursor == i {
			cursor = StyleSelected.Render("> ")
			style = StyleSelected
		}
		
		for _, selected := range m.SelectedAgents {
			if selected.ID == a.ID {
				checked = StyleSelected.Render("[x]")
				break
			}
		}
		
		sb.WriteString(fmt.Sprintf("%s%s %s\n", cursor, checked, style.Render(a.Name)))
	}

	if len(m.AllAgents) > pageSize {
		sb.WriteString(fmt.Sprintf("\n%s\n", StyleHint.Render(fmt.Sprintf("--- %d more agents below ---", len(m.AllAgents)-m.ListOffset-pageSize))))
	}

	sb.WriteString("\n" + StyleHint.Render("Space to toggle, Enter to continue, 'p' for preview"))
	return sb.String()
}

func (m MainModel) viewSkills() string {
	pageSize := 10
	var sb strings.Builder
	sb.WriteString("Inferred Skills\n")
	sb.WriteString(StyleHint.Render("Inferred from your project details and intake answers") + "\n\n")

	for i := m.ListOffset; i < m.ListOffset+pageSize && i < len(m.SelectedSkills); i++ {
		s := m.SelectedSkills[i]
		cursor := "  "
		style := StyleUnselected
		if m.Cursor == i {
			cursor = StyleSelected.Render("> ")
			style = StyleSelected
		}
		
		conf := strings.Repeat("", s.Confidence)
		sb.WriteString(fmt.Sprintf("%s%s  %s  %s\n", cursor, style.Render(s.Name), StyleHint.Render(conf), StyleHint.Render("("+s.Category+")")))
	}

	if len(m.SelectedSkills) > pageSize {
		sb.WriteString(fmt.Sprintf("\n%s\n", StyleHint.Render(fmt.Sprintf("--- %d more skills below ---", len(m.SelectedSkills)-m.ListOffset-pageSize))))
	}

	sb.WriteString("\n" + StyleHint.Render("Press Enter to continue"))
	return sb.String()
}

func (m MainModel) viewReview() string {
	var sb strings.Builder
	sb.WriteString("Ready to Scaffold?\n\n")
	sb.WriteString(fmt.Sprintf("Project:   %s\n", StyleSelected.Render(m.Project.Name)))
	sb.WriteString(fmt.Sprintf("Type:      %s\n", m.Project.TypeLabel))
	sb.WriteString(fmt.Sprintf("Agents:    %d selected\n", len(m.SelectedAgents)))
	sb.WriteString(fmt.Sprintf("Skills:    %d inferred\n", len(m.SelectedSkills)))
	sb.WriteString(fmt.Sprintf("Mode:      %s\n", map[bool]string{true: "Advanced", false: "Standard"}[m.Advanced]))
	
	if m.Advanced {
		sb.WriteString(fmt.Sprintf("Audience:  %s\n", m.Project.AudienceLabel))
		sb.WriteString(fmt.Sprintf("Scale:     %s\n", m.Project.ScaleLabel))
	}

	sb.WriteString("\n\n")
	if m.Confirming {
		sb.WriteString(lipgloss.NewStyle().Foreground(ColorWarning).Bold(true).Render("?? ARE YOU SURE? All files in the target directory will be created."))
		sb.WriteString("\n" + StyleSelected.Render("Press Enter to CONFIRM, or Esc to go back."))
	} else {
		sb.WriteString(StyleSelected.Render("Press Enter to begin scaffolding..."))
	}

	return sb.String()
}
