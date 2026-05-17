package tui

import "github.com/charmbracelet/lipgloss"

var (
	// Colors
	ColorBrand     = lipgloss.Color("#00D2C8") // Teal/Cyan (matching ps1 0, 210, 200)
	ColorSecondary = lipgloss.Color("#7F5AF0") // Violet/Purple
	ColorSuccess   = lipgloss.Color("#2CB67D") // Green
	ColorWarning   = lipgloss.Color("#F3AF22") // Amber
	ColorError     = lipgloss.Color("#EF4565") // Red
	ColorGray      = lipgloss.Color("#94A1B2") // Muted gray
	ColorSidebar   = lipgloss.Color("#16161A") // Dark sidebar background
	ColorBg        = lipgloss.Color("#010101") // Very dark background

	// Styles
	TitleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorBrand)

	SubtleStyle = lipgloss.NewStyle().
			Foreground(ColorGray).
			Italic(true)

	PrimaryStyle = lipgloss.NewStyle().
			Foreground(ColorBrand)

	StyleTitle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorBrand)

	StyleStepActive = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorBrand)

	StyleStepDone = lipgloss.NewStyle().
			Foreground(ColorSuccess)

	StyleStepDim = lipgloss.NewStyle().
			Foreground(ColorGray)

	StyleSidebar = lipgloss.NewStyle().
			Width(26).
			Padding(1, 2).
			Border(lipgloss.NormalBorder(), false, true, false, false).
			BorderForeground(lipgloss.Color("#24242E"))

	StyleContent = lipgloss.NewStyle().
			Padding(1, 4)

	StyleSelected = lipgloss.NewStyle().
			Foreground(ColorBrand).
			Bold(true)

	StyleUnselected = lipgloss.NewStyle().
			Foreground(ColorGray)

	StyleHint = lipgloss.NewStyle().
			Foreground(ColorGray).
			Italic(true)
)

// Icons
const (
	IconDone   = ""
	IconActive = "?"
	IconDot    = ""
)

const BrandLogo = `
  __  __     _             _ 
 |  \/  |___(_)_ _  __ _ (_)
 | |\/| (_-<| | ' \/ _' || |
 |_|  |_/__/|_|_||_\__, ||_|
                    |___/    `
