package engine

import (
	"math"
	"regexp"
	"strings"

	"github.com/xdagee/msingi/internal/models"
)

type InferenceResult struct {
	TypeID          string
	TypeLabel       string
	Goals           []string
	Features        []string
	Confidence      float64
	FieldConfidence map[string]float64
}

var typeTriggers = map[string][]string{
	"web-app":     {"web", "website", "dashboard", "frontend", "spa", "react", "nextjs", "vue"},
	"api-service": {"api", "backend", "service", "rest", "graphql", "server", "microservice"},
	"cli-tool":    {"cli", "terminal", "command line", "tool", "script", "automation", "binary"},
	"android":     {"android", "mobile", "app", "ios", "native", "kotlin", "flutter"},
	"desktop":     {"desktop", "windows", "macos", "linux", "electron", "gui"},
}

var goalKeywords = map[string][]string{
	"Automate Workflow":  {"automate", "workflow", "speed up", "efficiency", "streamline"},
	"Real-time Tracking": {"real-time", "tracking", "live", "monitor", "dashboard"},
	"User Collaboration": {"collaboration", "team", "share", "social", "chat"},
	"Data Analytics":     {"analytics", "insight", "report", "data", "chart", "graph"},
	"Secure Auth":        {"secure", "auth", "login", "identity", "protect"},
}

var featureKeywords = map[string][]string{
	"Authentication":     {"login", "auth", "signup", "jwt", "oauth", "password"},
	"Database":           {"database", "sql", "nosql", "postgres", "mongo", "sqlite", "store"},
	"Real-time Sync":     {"real-time", "websocket", "live", "sync", "socket"},
	"Payment Processing": {"payment", "stripe", "checkout", "billing", "subscribe"},
	"Push Notifications": {"notification", "push", "alert", "email", "sms"},
	"File Upload":        {"upload", "file", "image", "s3", "storage"},
}

func InferFeatures(description string) (*InferenceResult, error) {
	res := &InferenceResult{
		Goals:           []string{},
		Features:        []string{},
		FieldConfidence: make(map[string]float64),
	}

	lowDesc := strings.ToLower(description)

	// 1. Infer Project Type
	typeScores := make(map[string]int)
	for typeID, triggers := range typeTriggers {
		for _, trigger := range triggers {
			if strings.Contains(lowDesc, trigger) {
				typeScores[typeID]++
			}
		}
	}

	bestType := "web-app" // Default
	maxScore := 0
	for typeID, score := range typeScores {
		if score > maxScore {
			maxScore = score
			bestType = typeID
		}
	}
	res.TypeID = bestType
	res.TypeLabel = map[string]string{
		"web-app":     "Web App",
		"api-service": "API Service",
		"cli-tool":    "CLI Tool",
		"android":     "Android App",
		"desktop":     "Desktop App",
	}[bestType]
	
	if maxScore > 0 {
		res.FieldConfidence["Type"] = math.Min(1.0, float64(maxScore)/2.0)
	}

	// 2. Infer Goals
	for goal, keywords := range goalKeywords {
		for _, kw := range keywords {
			if strings.Contains(lowDesc, kw) {
				res.Goals = append(res.Goals, goal)
				break
			}
		}
	}

	// 3. Infer Features
	for feature, keywords := range featureKeywords {
		for _, kw := range keywords {
			if strings.Contains(lowDesc, kw) {
				res.Features = append(res.Features, feature)
				break
			}
		}
	}

	// 4. Infer Auth, Data, Scale (Simple heuristic)
	if strings.Contains(lowDesc, "login") || strings.Contains(lowDesc, "auth") || strings.Contains(lowDesc, "password") {
		res.FieldConfidence["Auth"] = 0.9
	}
	if strings.Contains(lowDesc, "pii") || strings.Contains(lowDesc, "sensitive") || strings.Contains(lowDesc, "financial") {
		res.FieldConfidence["Data"] = 0.8
	}
	if strings.Contains(lowDesc, "enterprise") || strings.Contains(lowDesc, "global") || strings.Contains(lowDesc, "million") {
		res.FieldConfidence["Scale"] = 0.8
	}

	// 5. Calculate Overall Confidence
	totalMatches := maxScore + len(res.Goals) + len(res.Features)
	wordCount := len(strings.Fields(description))
	if wordCount == 0 {
		res.Confidence = 0
	} else {
		res.Confidence = math.Min(1.0, float64(totalMatches)/5.0)
	}

	return res, nil
}

// categoryWeights for skill inference
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

// InferredSkill extends the base Skill with inference metadata
type InferredSkill struct {
	models.Skill
	TriggerMatches []string
	Confidence     int
}

// InferSkills runs the two-pass inference algorithm to find relevant skills
// Moved from TUI to Engine for better architecture
func InferSkills(haystack string, typeID string, allSkills []models.Skill) []InferredSkill {
	maxSkills := 12

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
			re, err := regexp.Compile("(?i)" + regexp.QuoteMeta(s.Trigger))
			if err != nil {
				continue
			}

			matches := re.FindAllStringIndex(haystack, -1)
			if len(matches) > 0 {
				triggerMatches := make([]string, len(matches))
				for i, m := range matches {
					triggerMatches[i] = haystack[m[0]:m[1]]
				}

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

	// Add baseline skills
	for _, s := range allSkills {
		if s.Baseline {
			alreadyMatched := false
			for _, m := range matched {
				if m.ID == s.ID {
					alreadyMatched = true
					break
				}
			}

			if !alreadyMatched {
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

	if len(matched) > maxSkills {
		return matched[:maxSkills]
	}

	return matched
}
// InferAgents selects relevant agents based on inferred features
func InferAgents(features []string, allAgents []models.Agent) []models.Agent {
	var selected []models.Agent
	seen := make(map[string]bool)

	// Baselines
	baselineIDs := []string{"claude-code", "gemini-cli"}
	for _, id := range baselineIDs {
		for _, a := range allAgents {
			if a.ID == id {
				selected = append(selected, a)
				seen[id] = true
				break
			}
		}
	}

	// Feature-based additions
	for _, f := range features {
		fLow := strings.ToLower(f)
		for _, a := range allAgents {
			if seen[a.ID] {
				continue
			}
			
			// Map specific features to agents
			if (fLow == "frontend" || fLow == "ui") && a.ID == "opencode" {
				selected = append(selected, a)
				seen[a.ID] = true
			}
			if (fLow == "infra" || fLow == "deployment") && a.ID == "qwen-code" {
				selected = append(selected, a)
				seen[a.ID] = true
			}
			if (fLow == "testing" || fLow == "quality") && a.ID == "aider" {
				selected = append(selected, a)
				seen[a.ID] = true
			}
			if (strings.Contains(fLow, "shell") || strings.Contains(fLow, "automation")) && a.ID == "goose" {
				selected = append(selected, a)
				seen[a.ID] = true
			}
			if (strings.Contains(fLow, "python") || strings.Contains(fLow, "orchestration")) && a.ID == "deep-agents" {
				selected = append(selected, a)
				seen[a.ID] = true
			}
			if (strings.Contains(fLow, "synthesis") || strings.Contains(fLow, "refactor")) && a.ID == "forgecode" {
				selected = append(selected, a)
				seen[a.ID] = true
			}
			if (strings.Contains(fLow, "data") || strings.Contains(fLow, "schema") || strings.Contains(fLow, "plan")) && a.ID == "plandex" {
				selected = append(selected, a)
				seen[a.ID] = true
			}
		}
	}

	return selected
}
