package engine

import (
	"strings"

	"github.com/xdagee/msingi/internal/models"
)

// MapFeaturesToSkills bridges inferred features to actual skills from skills.json
func MapFeaturesToSkills(features []string, allSkills []models.Skill) []models.Skill {
	var selected []models.Skill
	seen := make(map[string]bool)

	for _, feature := range features {
		fLow := strings.ToLower(feature)
		for _, skill := range allSkills {
			if seen[skill.ID] {
				continue
			}

			// Check name, category, or description for feature keywords
			if strings.Contains(strings.ToLower(skill.Name), fLow) ||
				strings.Contains(strings.ToLower(skill.Category), fLow) ||
				strings.Contains(strings.ToLower(skill.Description), fLow) {
				selected = append(selected, skill)
				seen[skill.ID] = true
			}
		}
	}

	return selected
}
