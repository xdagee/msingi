package tui

import (
	"testing"
	tea "github.com/charmbracelet/bubbletea"
)

func TestUpdateMode(t *testing.T) {
	m := NewModel(nil, nil)
	
	// Test selection transition
	m2, _ := m.updateMode(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("j")}) // 'j' is down
	m3 := m2.(MainModel)
	// Cursor should move to 1
	if m3.Cursor != 1 {
		t.Errorf("Expected cursor 1 after 'j' key, got %d", m3.Cursor)
	}

	m4, _ := m3.updateMode(tea.KeyMsg{Type: tea.KeyEnter})
	m5 := m4.(MainModel)
	if m5.Step != StepType {
		t.Errorf("Expected step StepType after enter, got %v", m5.Step)
	}
}

func TestUpdateType(t *testing.T) {
	m := NewModel(nil, nil)
	m.Step = StepType
	
	m2, _ := m.updateType(tea.KeyMsg{Type: tea.KeyEnter})
	m3 := m2.(MainModel)
	if m3.Step != StepDetails {
		t.Errorf("Expected step StepDetails after enter, got %v", m3.Step)
	}
}
