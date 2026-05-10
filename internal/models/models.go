package models

import (
	"encoding/json"
)

// NativeConfig represents the nested config inside an Agent
type NativeConfig struct {
	ConfigDir *string  `json:"configDir"`
	Supports  []string `json:"supports"`
}

// Project represents the user's project context choices
type Project struct {
	Name                 string
	TypeLabel            string
	SecondaryTypeID      string
	SecondaryTypeLabel   string
	Description          string
	Audience             string
	AudienceLabel        string
	NeedsAuth            bool
	HandlesSensitiveData bool
	SensitiveTags        string
	DeploymentTarget     string
	DeployLabel          string
	ScaleProfile         string
	ScaleLabel           string
	Stack                string
	Architecture         string
	NFR                  string
	Milestone            string
	HasSkills            bool
	AgentLines           string
	DocsLines            string
	SkillLines           string
}

// Agent maps to a single object in agents.json
type Agent struct {
	ID              string        `json:"id"`
	Name            string        `json:"name"`
	File            string        `json:"file"`
	Scratchpad      string        `json:"scratchpad"`
	Category        string        `json:"category"`
	Repo            string        `json:"repo"`
	Description     string        `json:"description"`
	DocsUrl         string        `json:"docsUrl"`
	CapabilityToAct []string      `json:"capabilityToAct"`
	SelfDirection   string        `json:"selfDirection"`
	Roles           []string      `json:"roles"`
	NativeConfig    *NativeConfig `json:"nativeConfig"`
}

// AgentsData represents the root object of agents.json
type AgentsData struct {
	SchemaVersion string  `json:"schema_version"`
	Agents        []Agent `json:"agents"`
}

// Skill maps to a single object in skills.json
type Skill struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Category    string   `json:"category"`
	Description string   `json:"description"`
	Types       []string `json:"types"`
	Baseline    bool     `json:"baseline"`
	Trigger     string   `json:"trigger"`
}

// SkillsData represents the root object of skills.json
type SkillsData struct {
	SchemaVersion string  `json:"schema_version"`
	Skills        []Skill `json:"skills"`
}

// LoadAgents parses agents JSON byte data into AgentsData
func LoadAgents(data []byte) (*AgentsData, error) {
	var ad AgentsData
	err := json.Unmarshal(data, &ad)
	if err != nil {
		return nil, err
	}
	return &ad, nil
}

// LoadSkills parses skills JSON byte data into SkillsData
func LoadSkills(data []byte) (*SkillsData, error) {
	var sd SkillsData
	err := json.Unmarshal(data, &sd)
	if err != nil {
		return nil, err
	}
	return &sd, nil
}
