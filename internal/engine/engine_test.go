package engine

import (
	"os"
	"strings"
	"testing"

	"github.com/xdagee/msingi/internal/models"
)

func loadTestFiles(t *testing.T) ([]models.Agent, []models.Skill) {
	agentsData, err := os.ReadFile("../../agents.json")
	if err != nil {
		t.Fatalf("Failed to read agents.json: %v", err)
	}
	skillsData, err := os.ReadFile("../../skills.json")
	if err != nil {
		t.Fatalf("Failed to read skills.json: %v", err)
	}

	ad, err := models.LoadAgents(agentsData)
	if err != nil {
		t.Fatalf("Failed to parse agents: %v", err)
	}
	sd, err := models.LoadSkills(skillsData)
	if err != nil {
		t.Fatalf("Failed to parse skills: %v", err)
	}

	return ad.Agents, sd.Skills
}

func TestInferFeatures(t *testing.T) {
	tests := []struct {
		name        string
		description string
		wantType    string
		wantGoals   []string
		wantFeat    []string
	}{
		{
			name:        "Web App with Auth and Payments",
			description: "A secure react website that handles logins via JWT and checkout with Stripe billing",
			wantType:    "web-app",
			wantGoals:   []string{"Secure Auth"},
			wantFeat:    []string{"Authentication", "Payment Processing"},
		},
		{
			name:        "API Microservice with postgres",
			description: "High performance API microservice using postgres database store and webhook integration",
			wantType:    "api-service",
			wantGoals:   []string{},
			wantFeat:    []string{"Database"},
		},
		{
			name:        "CLI Tool with speed goals",
			description: "A terminal binary cli tool to streamline and automate fast builds",
			wantType:    "cli-tool",
			wantGoals:   []string{"Automate Workflow"},
			wantFeat:    []string{},
		},
		{
			name:        "Android Kotlin Mobile App",
			description: "An android app written in Kotlin for social network collaboration with team posts and live dashboard",
			wantType:    "android",
			wantGoals:   []string{"Real-time Tracking", "User Collaboration"},
			wantFeat:    []string{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res, err := InferFeatures(tt.description)
			if err != nil {
				t.Fatalf("InferFeatures failed: %v", err)
			}
			if res.TypeID != tt.wantType {
				t.Errorf("Expected TypeID %q, got %q", tt.wantType, res.TypeID)
			}

			// Validate goal containment
			for _, g := range tt.wantGoals {
				found := false
				for _, rg := range res.Goals {
					if rg == g {
						found = true
						break
					}
				}
				if !found {
					t.Errorf("Expected goal %q in inferred goals %v", g, res.Goals)
				}
			}

			// Validate feature containment
			for _, f := range tt.wantFeat {
				found := false
				for _, rf := range res.Features {
					if rf == f {
						found = true
						break
					}
				}
				if !found {
					t.Errorf("Expected feature %q in inferred features %v", f, res.Features)
				}
			}
		})
	}
}

func TestInferSkills(t *testing.T) {
	_, allSkills := loadTestFiles(t)

	t.Run("Empty Input", func(t *testing.T) {
		res := InferSkills("", "web-app", allSkills)
		// Should only return baseline skills for web-app
		for _, s := range res {
			if !s.Baseline {
				t.Errorf("Expected only baseline skills, got non-baseline: %s", s.ID)
			}
		}
	})

	t.Run("Trigger Match Confidence Sorting", func(t *testing.T) {
		// "postgres secure login" triggers "data" and "auth" categories, which are high-weighted
		res := InferSkills("postgres secure login and database migration", "web-app", allSkills)
		
		if len(res) == 0 {
			t.Fatalf("Expected some skills, got 0")
		}

		// Ensure sorted by confidence descending
		for i := 0; i < len(res)-1; i++ {
			if res[i].Confidence < res[i+1].Confidence {
				t.Errorf("Skills not sorted by confidence: skill %s has %d, but subsequent skill %s has %d",
					res[i].ID, res[i].Confidence, res[i+1].ID, res[i+1].Confidence)
			}
		}
	})

	t.Run("Max Skills Truncation", func(t *testing.T) {
		// Mock massive list of skills to hit maxSkills=12 limit
		massiveSkills := make([]models.Skill, 20)
		for i := 0; i < 20; i++ {
			massiveSkills[i] = models.Skill{
				ID:       string(rune('a' + i)),
				Name:     "Baseline Skill",
				Category: "infra",
				Baseline: true,
			}
		}
		res := InferSkills("", "web-app", massiveSkills)
		if len(res) > 12 {
			t.Errorf("Expected at most 12 truncated skills, got %d", len(res))
		}
	})
}

func TestInferAgents(t *testing.T) {
	allAgents, _ := loadTestFiles(t)

	t.Run("Baseline Agents Always Included", func(t *testing.T) {
		res := InferAgents([]string{}, allAgents)
		
		// Ensure claude-code and gemini-cli are present
		hasClaude := false
		hasGemini := false
		for _, a := range res {
			if a.ID == "claude-code" {
				hasClaude = true
			}
			if a.ID == "gemini-cli" {
				hasGemini = true
			}
		}
		if !hasClaude || !hasGemini {
			t.Errorf("Baseline agents missing. Has Claude: %t, Has Gemini: %t", hasClaude, hasGemini)
		}
	})

	t.Run("Feature Mapping", func(t *testing.T) {
		res := InferAgents([]string{"testing", "synthesis"}, allAgents)
		
		hasAider := false
		hasForgeCode := false
		for _, a := range res {
			if a.ID == "aider" {
				hasAider = true
			}
			if a.ID == "forgecode" {
				hasForgeCode = true
			}
		}
		if !hasAider || !hasForgeCode {
			t.Errorf("Feature-to-agent mapping failed. Has Aider: %t, Has ForgeCode: %t", hasAider, hasForgeCode)
		}
	})
}

func TestSuggestTechStack(t *testing.T) {
	tests := []struct {
		typeID    string
		skills    []models.Skill
		wantStack []string
	}{
		{
			typeID:    "web-app",
			skills:    []models.Skill{{Category: "auth"}, {Category: "data"}},
			wantStack: []string{"Next.js", "Tailwind CSS", "TypeScript", "NextAuth.js", "Prisma ORM"},
		},
		{
			typeID:    "api-service",
			skills:    []models.Skill{},
			wantStack: []string{"Go", "Gin/Fiber", "PostgreSQL"},
		},
		{
			typeID:    "cli-tool",
			skills:    []models.Skill{{Category: "data"}},
			wantStack: []string{"Go", "Bubble Tea", "Lipgloss", "SQLite"},
		},
		{
			typeID:    "android",
			skills:    []models.Skill{},
			wantStack: []string{"Kotlin", "Jetpack Compose", "Coroutines"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.typeID, func(t *testing.T) {
			proj := &models.Project{TypeID: tt.typeID}
			res := SuggestTechStack(proj, tt.skills)
			for _, item := range tt.wantStack {
				if !strings.Contains(res, item) {
					t.Errorf("Expected stack to contain %q, but got %q", item, res)
				}
			}
		})
	}
}

func TestMapFeaturesToSkills(t *testing.T) {
	_, allSkills := loadTestFiles(t)

	res := MapFeaturesToSkills([]string{"Authentication", "database", "Authentication"}, allSkills)

	// Verify deduplication
	seen := make(map[string]bool)
	for _, s := range res {
		if seen[s.ID] {
			t.Errorf("Duplicate skill found: %s", s.ID)
		}
		seen[s.ID] = true
	}

	// Verify matches
	hasAuth := false
	hasData := false
	for _, s := range res {
		if s.Category == "auth" {
			hasAuth = true
		}
		if s.Category == "data" {
			hasData = true
		}
	}
	if !hasAuth || !hasData {
		t.Errorf("Expected mapping to match auth and data skills. Has Auth: %t, Has Data: %t", hasAuth, hasData)
	}
}
