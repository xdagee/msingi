package tui

import (
	"testing"
	tea "github.com/charmbracelet/bubbletea"
)

func TestUpdateStep(t *testing.T) {
	m := NewModel(nil, nil)
	m.Step = StepSummary
	
	// Test selection transition
	m2, _ := m.updateStep(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("j")}) // 'j' is down
	m3 := m2.(MainModel)
	// Cursor should move to 1
	if m3.Cursor != 1 {
		t.Errorf("Expected cursor 1 after 'j' key, got %d", m3.Cursor)
	}

	// At cursor 1, enter should go to StepDescribe
	m4, _ := m3.updateStep(tea.KeyMsg{Type: tea.KeyEnter})
	m5 := m4.(MainModel)
	if m5.Step != StepDescribe {
		t.Errorf("Expected step StepDescribe after enter, got %v", m5.Step)
	}
}

func TestUpdateWelcome(t *testing.T) {
	m := NewModel(nil, nil)
	m.Step = StepWelcome
	
	m2, _ := m.updateStep(tea.KeyMsg{Type: tea.KeyEnter})
	m3 := m2.(MainModel)
	if m3.Step != StepDescribe {
		t.Errorf("Expected step StepDescribe after enter, got %v", m3.Step)
	}
}
