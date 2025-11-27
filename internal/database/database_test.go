package database

import "testing"

func TestScriptExecutorIgnoresSystems(t *testing.T) {
	executor := NewScriptExecutor(nil, []string{"test_system", "ignored"})
	
	if !executor.isSystemIgnored("test_system") {
		t.Error("Expected test_system to be ignored")
	}
	
	if !executor.isSystemIgnored("ignored") {
		t.Error("Expected ignored to be ignored")
	}
	
	if executor.isSystemIgnored("active_system") {
		t.Error("Expected active_system to not be ignored")
	}
}

func TestSplitStatements(t *testing.T) {
	executor := NewScriptExecutor(nil, nil)
	
	script := `SELECT 1; SELECT 2; SELECT 3;`
	
	statements := executor.splitStatements(script)
	
	if len(statements) != 3 {
		t.Errorf("Expected 3 statements, got %d", len(statements))
	}
}
