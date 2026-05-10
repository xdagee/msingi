package tui

import (
	"math"
	"regexp"

	"github.com/xdagee/msingi/internal/models"
)

// InferredSkill extends the base Skill with inference metadata
type InferredSkill struct {
	models.Skill
	TriggerMatches []string
	Confidence     int
}

var categoryWeights = map[string]float64{
	"auth":      1.5,
	"data":      1.2,
	"api":       1.0,
	"infra":     0.9,
	"testing":   0.9,
	"messaging": 0.9,
	"ui":        0.8,
	"ml":        0.8,
	"android":   0.8,
}

// InferSkills runs the two-pass inference algorithm to find relevant skills
func InferSkills(haystack string, typeID string, allSkills []models.Skill) []InferredSkill {
	maxSkills := 12 // Matches MAX_SKILLS in ps1

	// Pass 1 & 2: Scope to type and match triggers
	var matched []InferredSkill
	for _, s := range allSkills {
		// Scoping
		typeMatch := len(s.Types) == 0
		for _, t := range s.Types {
			if t == typeID {
				typeMatch = true
				break
			}
		}

		if !typeMatch {
			continue
		}

		// Trigger Matching
		if s.Trigger != "" {
			re, err := regexp.Compile("(?i)" + s.Trigger)
			if err != nil {
				continue
			}

			matches := re.FindAllStringIndex(haystack, -1)
			if len(matches) > 0 {
				triggerMatches := make([]string, len(matches))
				for i, m := range matches {
					triggerMatches[i] = haystack[m[0]:m[1]]
				}

				// Calculate confidence
				weight := 0.8
				if w, ok := categoryWeights[s.Category]; ok {
					weight = w
				}

				firstPos := float64(matches[0][0])
				descLen := float64(len(haystack))
				if descLen == 0 {
					descLen = 1
				}
				posBonus := 1.0 + (0.1 * (1.0 - (firstPos / descLen)))
				
				conf := math.Min(5, math.Round(float64(len(triggerMatches))*weight*posBonus))

				matched = append(matched, InferredSkill{
					Skill:          s,
					TriggerMatches: triggerMatches,
					Confidence:     int(conf),
				})
			}
		}
	}

	// Pass 3: Add baseline skills (scoped to type) if not already matched
	for _, s := range allSkills {
		if s.Baseline {
			// Check if already matched
			alreadyMatched := false
			for _, m := range matched {
				if m.ID == s.ID {
					alreadyMatched = true
					break
				}
			}

			if !alreadyMatched {
				// Scoping check for baseline
				typeMatch := len(s.Types) == 0
				for _, t := range s.Types {
					if t == typeID {
						typeMatch = true
						break
					}
				}

				if typeMatch {
					matched = append(matched, InferredSkill{
						Skill:          s,
						TriggerMatches: []string{},
						Confidence:     1,
					})
				}
			}
		}
	}

	// Limit to max skills
	if len(matched) > maxSkills {
		return matched[:maxSkills]
	}

	return matched
}
