package engine

import (
	"strings"

	"github.com/xdagee/msingi/internal/models"
)

// SuggestTechStack recommends a tech stack based on project type and skills
func SuggestTechStack(project *models.Project, skills []models.Skill) string {
	var stack []string

	// Base stack by type
	switch project.TypeID {
	case "web-app":
		stack = append(stack, "Next.js", "Tailwind CSS", "TypeScript")
	case "api-service":
		stack = append(stack, "Go", "Gin/Fiber", "PostgreSQL")
	case "cli-tool":
		stack = append(stack, "Go", "Bubble Tea", "Lipgloss")
	case "android":
		stack = append(stack, "Kotlin", "Jetpack Compose", "Coroutines")
	case "desktop":
		stack = append(stack, "Go", "Wails", "Vite/React")
	default:
		stack = append(stack, "Go", "Markdown")
	}

	// Skill-specific additions
	for _, s := range skills {
		switch s.Category {
		case "auth":
			if !contains(stack, "NextAuth.js") && project.TypeID == "web-app" {
				stack = append(stack, "NextAuth.js")
			}
		case "data":
			if !contains(stack, "Prisma") && project.TypeID == "web-app" {
				stack = append(stack, "Prisma ORM")
			} else if !contains(stack, "SQLite") && project.TypeID == "cli-tool" {
				stack = append(stack, "SQLite")
			}
		case "messaging":
			stack = append(stack, "Redis", "Socket.io")
		case "ml":
			stack = append(stack, "Python", "PyTorch", "HuggingFace")
		}
	}

	return strings.Join(stack, ", ")
}

func contains(slice []string, val string) bool {
	for _, item := range slice {
		if item == val {
			return true
		}
	}
	return false
}
