package models

// NativeConfig represents the nested config inside an Agent
type NativeConfig struct {
	ConfigDir *string  `json:"configDir"`
	Supports  []string `json:"supports"`
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
	Baseline        bool          `json:"baseline,omitempty"`
	NativeConfig    *NativeConfig `json:"nativeConfig"`
}

// AgentsData represents the root object of agents.json
type AgentsData struct {
	SchemaVersion string  `json:"schema_version"`
	Agents        []Agent `json:"agents"`
}
