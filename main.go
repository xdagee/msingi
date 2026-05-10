package main

import (
	"embed"
	"flag"
	"fmt"
	"os"

	"github.com/xdagee/msingi/internal/builders"
	"github.com/xdagee/msingi/internal/engine"
	"github.com/xdagee/msingi/internal/generator"
	"github.com/xdagee/msingi/internal/models"
	"github.com/xdagee/msingi/internal/tui"
)

const version = "4.1.0"

//go:embed templates/*
var templatesFS embed.FS

//go:embed agents.json
var agentsJSON []byte

//go:embed skills.json
var skillsJSON []byte

func main() {
	testHarness := flag.Bool("test-harness", false, "Run in headless mode for parity testing")
	builder := flag.String("builder", "", "Which builder to run (e.g. quality, plans, inbox)")
	project := flag.String("project", "", "Project name to inject")
	agentID := flag.String("agent-id", "", "Agent ID to inject")
	skillID := flag.String("skill-id", "", "Skill ID to inject")
	verbose := flag.Bool("verbose", false, "Enable detailed logging and warnings")
	dryRun := flag.Bool("dry-run", false, "Preview generation without writing to disk")
	templateDir := flag.String("template-dir", "", "Path to local templates for hot-reloading")
	flag.Parse()

	if *verbose {
		fmt.Printf("Msingi v%s Verbose Mode: Enabled\n", version)
	}

	if err := engine.ValidateTemplates(templatesFS, *verbose); err != nil {
		fmt.Fprintf(os.Stderr, "Template Validation Failed: %v\n", err)
		os.Exit(1)
	}

	eng := engine.NewEngine(templatesFS, *templateDir)

	agents, err := models.LoadAgents(agentsJSON)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing agents.json: %v\n", err)
		os.Exit(1)
	}

	skills, err := models.LoadSkills(skillsJSON)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing skills.json: %v\n", err)
		os.Exit(1)
	}

	if *testHarness {
		proj := &models.Project{
			Name:                 os.Getenv("PROJECT_NAME"),
			TypeLabel:            os.Getenv("PROJECT_TYPE_LABEL"),
			SecondaryTypeID:      os.Getenv("PROJECT_SECONDARY_TYPE_ID"),
			SecondaryTypeLabel:   os.Getenv("PROJECT_SECONDARY_TYPE_LABEL"),
			Description:          os.Getenv("PROJECT_DESCRIPTION"),
			Audience:             os.Getenv("PROJECT_AUDIENCE"),
			AudienceLabel:        os.Getenv("PROJECT_AUDIENCE_LABEL"),
			NeedsAuth:            os.Getenv("PROJECT_NEEDS_AUTH") == "true",
			HandlesSensitiveData: os.Getenv("PROJECT_HANDLES_SENSITIVE_DATA") == "true",
			SensitiveTags:        os.Getenv("PROJECT_SENSITIVE_TAGS"),
			DeploymentTarget:     os.Getenv("PROJECT_DEPLOYMENT_TARGET"),
			DeployLabel:          os.Getenv("PROJECT_DEPLOY_LABEL"),
			ScaleProfile:         os.Getenv("PROJECT_SCALE_PROFILE"),
			ScaleLabel:           os.Getenv("PROJECT_SCALE_LABEL"),
			Stack:                os.Getenv("PROJECT_STACK"),
			Architecture:         os.Getenv("PROJECT_ARCHITECTURE"),
			NFR:                  os.Getenv("PROJECT_NFR"),
			Milestone:            os.Getenv("PROJECT_MILESTONE"),
			HasSkills:            os.Getenv("HAS_SKILLS") == "true",
			AgentLines:           os.Getenv("AGENT_LINES"),
			DocsLines:            os.Getenv("DOCS_LINES"),
			SkillLines:           os.Getenv("SKILL_LINES"),
		}

		if *project != "" {
			proj.Name = *project
		}

		var output string

		switch *builder {
		case "plans":
			output = builders.BuildPlansMd(eng)
		case "plan_template":
			output = builders.BuildPlanTemplateMd(eng)
		case "inbox":
			output = builders.BuildInboxMd(eng)
		case "quality":
			output = builders.BuildQualityMd(eng, proj.Name)
		case "observability":
			output = builders.BuildObservabilityMd(eng, proj.Name)
		case "context":
			output = builders.BuildContextMd(eng, proj)
		case "tasks":
			output = builders.BuildTasksMd(eng, proj)
		case "workstreams":
			output = builders.BuildWorkstreamsMd(eng, proj, agents.Agents, skills.Skills)
		case "trajectory":
			output = builders.BuildTrajectoryMd(eng, proj)
		case "agent":
			if *agentID == "" {
				fmt.Fprintln(os.Stderr, "--agent-id required for agent builder")
				os.Exit(1)
			}
			var targetAgent *models.Agent
			for _, a := range agents.Agents {
				if a.ID == *agentID {
					targetAgent = &a
					break
				}
			}
			if targetAgent == nil {
				fmt.Fprintf(os.Stderr, "Agent %s not found\n", *agentID)
				os.Exit(1)
			}
			output = builders.BuildAgentMd(eng, targetAgent, proj)
		case "skill_spec":
			if *skillID == "" {
				fmt.Fprintln(os.Stderr, "--skill-id required for skill builders")
				os.Exit(1)
			}
			var targetSkill *models.Skill
			for _, s := range skills.Skills {
				if s.ID == *skillID {
					targetSkill = &s
					break
				}
			}
			if targetSkill == nil {
				fmt.Fprintf(os.Stderr, "Skill %s not found\n", *skillID)
				os.Exit(1)
			}
			output = builders.BuildSkillSpecMd(eng, targetSkill, proj)
		case "skill_gotchas":
			if *skillID == "" {
				fmt.Fprintln(os.Stderr, "--skill-id required for skill builders")
				os.Exit(1)
			}
			var targetSkill *models.Skill
			for _, s := range skills.Skills {
				if s.ID == *skillID {
					targetSkill = &s
					break
				}
			}
			if targetSkill == nil {
				fmt.Fprintf(os.Stderr, "Skill %s not found\n", *skillID)
				os.Exit(1)
			}
			output = builders.BuildSkillGotchasMd(eng, targetSkill, proj)
		case "skill_eval":
			if *skillID == "" {
				fmt.Fprintln(os.Stderr, "--skill-id required for skill builders")
				os.Exit(1)
			}
			var targetSkill *models.Skill
			for _, s := range skills.Skills {
				if s.ID == *skillID {
					targetSkill = &s
					break
				}
			}
			if targetSkill == nil {
				fmt.Fprintf(os.Stderr, "Skill %s not found\n", *skillID)
				os.Exit(1)
			}
			output = builders.BuildSkillEvalMd(eng, targetSkill, proj)
		default:
			fmt.Fprintf(os.Stderr, "Unknown builder: %s\n", *builder)
			os.Exit(1)
		}

		fmt.Print(output)
		os.Exit(0)
	}

	// Interactive Mode
	result, err := tui.Run(agents.Agents, skills.Skills)
	if err != nil {
		fmt.Fprintf(os.Stderr, "TUI error: %v\n", err)
		os.Exit(1)
	}

	if result == nil {
		fmt.Println("Scaffolding cancelled.")
		os.Exit(0)
	}

	// Logic to generate all files based on final project configuration
	if err := generator.Generate(eng, result.Project, result.SelectedAgents, result.SelectedSkills, *dryRun); err != nil {
		fmt.Fprintf(os.Stderr, "Generation error: %v\n", err)
		os.Exit(1)
	}

	// Sync metadata to session and save audit log
	result.Session.Project = *result.Project
	result.Session.Agents = result.SelectedAgents
	result.Session.Skills = result.SelectedSkills
	if err := result.Session.Save(result.Project.Name); err != nil {
		fmt.Fprintf(os.Stderr, "Audit Log Save error: %v\n", err)
	}

	fmt.Printf("\nScaffolding complete: %s\n", result.Project.Name)
	os.Exit(0)
}
