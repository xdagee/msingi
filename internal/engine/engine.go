package engine

import (
	"embed"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Engine holds the embedded filesystem to read templates from
type Engine struct {
	FS        embed.FS
	LocalPath string
}

// NewEngine creates a new template engine
func NewEngine(fs embed.FS, localPath string) *Engine {
	return &Engine{FS: fs, LocalPath: localPath}
}

// RenderTemplate reads a template file from the embedded FS and substitutes tokens
func (e *Engine) RenderTemplate(templateName string, tokens map[string]string) string {
	var data []byte
	var err error

	if e.LocalPath != "" {
		path := filepath.Join(e.LocalPath, templateName)
		data, err = os.ReadFile(path)
	}

	if data == nil {
		path := "templates/" + templateName
		data, err = e.FS.ReadFile(path)
	}

	if err != nil {
		return fmt.Sprintf("ERROR: Template %s not found (err: %v).", templateName, err)
	}

	content := string(data)
	for key, val := range tokens {
		content = strings.ReplaceAll(content, "{{"+key+"}}", val)
	}

	return content
}
