package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/xdagee/msingi/internal/engine"
	"github.com/xdagee/msingi/internal/models"
)

func (m MainModel) renderContent() string {
	switch m.Step {
	case StepWelcome:
		return m.viewWelcome()
	case StepDescribe:
		return m.viewDescribe()
	case StepSummary:
		return m.viewSummary()
	case StepClarify:
		return m.viewClarify()
	case StepGenerate:
		return m.viewGenerate()
	case StepDone:
		return m.viewDone()
	default:
		return "Unknown Step"
	}
}

func (m MainModel) viewWelcome() string {
	logo := lipgloss.NewStyle().
		Foreground(ColorBrand).
		Bold(true).
		Render(BrandLogo)

	tagline := lipgloss.NewStyle().
		Italic(true).
		Foreground(ColorSecondary).
		Render("Built in Accra. Designed for everywhere.")

	explanation := lipgloss.NewStyle().
		Width(60).
		Align(lipgloss.Center).
		Render("Msingi generates a production-grade multi-agent scaffold based on your project description. We'll infer your tech stack, goals, and required skills automatically.")

	content := lipgloss.JoinVertical(
		lipgloss.Center,
		logo,
		tagline,
		"",
		explanation,
		"",
		lipgloss.NewStyle().Bold(true).Render("Press Enter to start project onboarding..."),
	)

	return lipgloss.Place(m.Width-30, m.Height, lipgloss.Center, lipgloss.Center, content)
}

func (m MainModel) viewDescribe() string {
	titleStr := "Project Name"
	helpStr := "Enter a concise name for your project."
	inputView := m.TextInput.View()
	footer := SubtleStyle.Render("Enter: Confirm")

	if m.Project.Name != "" {
		titleStr = "Describe your project"
		helpStr = "Be as specific as possible about goals, features, and target audience."
		inputView = m.TextArea.View()
		footer = SubtleStyle.Render("Ctrl+D or Ctrl+Enter: Confirm description")
	}
	
	title := TitleStyle.Render(titleStr)
	help := SubtleStyle.Render(helpStr)
	
	return lipgloss.JoinVertical(
		lipgloss.Left,
		title,
		"",
		help,
		"",
		inputView,
		"",
		footer,
	)
}

func (m MainModel) viewSummary() string {
	title := TitleStyle.Render("Inference Summary")
	
	// Helper for highlighting low confidence
	hl := func(label string, val string, field string) string {
		conf := m.FieldConfidence[field]
		style := lipgloss.NewStyle()
		prefix := ""
		if conf > 0 && conf < 0.6 {
			style = style.Foreground(ColorWarning).Bold(true)
			prefix = "⚠ "
		}
		return fmt.Sprintf("%s: %s", label, style.Render(prefix+val))
	}

	// Left column: Inferred Info
	leftCol := lipgloss.NewStyle().Width((m.Width-30)/2).Render(
		lipgloss.JoinVertical(lipgloss.Left,
			lipgloss.NewStyle().Bold(true).Render("Inferred Metadata"),
			hl("Type", m.Project.TypeLabel, "Type"),
			hl("Auth", fmt.Sprintf("%v", m.Project.NeedsAuth), "Auth"),
			hl("Data", m.Project.SensitiveTags, "Data"),
			hl("Scale", m.Project.ScaleLabel, "Scale"),
			"",
			lipgloss.NewStyle().Bold(true).Render("Inferred Goals"),
			strings.Join(m.Project.InferredGoals, "\n"),
		),
	)

	// Right column: Suggested Stack & Skills
	rightCol := lipgloss.NewStyle().Width((m.Width-30)/2).Render(
		lipgloss.JoinVertical(lipgloss.Left,
			lipgloss.NewStyle().Bold(true).Render("Suggested Stack"),
			m.Project.Stack,
			"",
			lipgloss.NewStyle().Bold(true).Render("Inferred Agents"),
			renderAgentList(m.SelectedAgents),
			"",
			lipgloss.NewStyle().Bold(true).Render("Inferred Skills"),
			renderSkillList(m.InferredSkills),
		),
	)

	columns := lipgloss.JoinHorizontal(lipgloss.Top, leftCol, rightCol)

	options := []string{"Accept & Generate", "Edit Description", "Review Clarifications"}
	var optsView strings.Builder
	for i, opt := range options {
		if m.Cursor == i {
			optsView.WriteString(StyleSelected.Render(fmt.Sprintf("> %s", opt)) + "\n")
		} else {
			optsView.WriteString(StyleUnselected.Render(fmt.Sprintf("  %s", opt)) + "\n")
		}
	}

	return lipgloss.JoinVertical(
		lipgloss.Left,
		title,
		"",
		columns,
		"",
		lipgloss.NewStyle().Bold(true).Render("Action:"),
		optsView.String(),
		"",
		SubtleStyle.Render("⚠ Amber fields indicate low inference confidence."),
	)
}

func renderSkillList(skills []engine.InferredSkill) string {
	var sb strings.Builder
	for _, s := range skills {
		sb.WriteString(fmt.Sprintf("- %s (%d)\n", s.Name, s.Confidence))
	}
	return sb.String()
}

func renderAgentList(agents []models.Agent) string {
	var sb strings.Builder
	for _, a := range agents {
		sb.WriteString(fmt.Sprintf("- %s\n", a.Name))
	}
	return sb.String()
}

func (m MainModel) viewClarify() string {
	questions := []string{"Audience", "Auth", "Data", "Deploy", "Scale"}
	options := [][]string{
		{"Public", "Internal", "B2B", "Mobile"},
		{"Yes", "No"},
		{"None", "PII/PHI", "Financial", "System Secrets"},
		{"Cloud", "On-premises", "Edge", "Mobile store"},
		{"Personal", "Small team", "Growth", "Enterprise"},
	}

	currentOptions := options[m.IntakeStep]
	title := TitleStyle.Render(fmt.Sprintf("Clarification: %s", questions[m.IntakeStep]))
	help := SubtleStyle.Render("Msingi was unsure about this field based on your description.")

	var sb strings.Builder
	for i, opt := range currentOptions {
		if m.Cursor == i {
			sb.WriteString(StyleSelected.Render(fmt.Sprintf("> %s", opt)) + "\n")
		} else {
			sb.WriteString(StyleUnselected.Render(fmt.Sprintf("  %s", opt)) + "\n")
		}
	}

	return lipgloss.JoinVertical(
		lipgloss.Left,
		title,
		help,
		"",
		sb.String(),
		"",
		SubtleStyle.Render("Enter: Select • Esc: Back to Summary"),
	)
}

func (m MainModel) viewGenerate() string {
	return lipgloss.Place(m.Width-30, m.Height, lipgloss.Center, lipgloss.Center,
		fmt.Sprintf("%s Generating Msingi scaffold...", m.Spinner.View()))
}

func (m MainModel) viewDone() string {
	title := TitleStyle.Render("Scaffolding Complete! 🎉")
	
	summary := lipgloss.JoinVertical(lipgloss.Left,
		fmt.Sprintf("Project: %s", m.Project.Name),
		fmt.Sprintf("Type: %s", m.Project.TypeLabel),
		fmt.Sprintf("Stack: %s", m.Project.Stack),
	)

	return lipgloss.Place(m.Width-30, m.Height, lipgloss.Center, lipgloss.Center,
		lipgloss.JoinVertical(lipgloss.Center,
			title,
			"",
			summary,
			"",
			"Your multi-agent infrastructure is ready.",
			"Press Q to exit.",
		),
	)
}

func (m MainModel) renderSidebar() string {
	style := StyleSidebar.Height(m.Height)

	steps := []string{"Welcome", "Description", "Summary", "Clarify", "Generate", "Done"}
	var sb strings.Builder
	sb.WriteString(lipgloss.NewStyle().Bold(true).Foreground(ColorBrand).Render("MSINGI FLOW") + "\n\n")

	for i, step := range steps {
		s := lipgloss.NewStyle()
		if int(m.Step) == i {
			s = StyleStepActive
			sb.WriteString(s.Render(fmt.Sprintf("● %s", step)) + "\n")
		} else if int(m.Step) > i {
			s = StyleStepDone
			sb.WriteString(s.Render(fmt.Sprintf("✓ %s", step)) + "\n")
		} else {
			s = StyleStepDim
			sb.WriteString(s.Render(fmt.Sprintf("○ %s", step)) + "\n")
		}
	}

	return style.Render(sb.String())
}
