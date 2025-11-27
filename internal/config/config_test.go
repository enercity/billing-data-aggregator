package config

import (
	"os"
	"testing"
)

func TestLoad(t *testing.T) {
	if err := os.Setenv("BDA_CLIENT_ID", "test-client"); err != nil {
		t.Fatalf("Failed to set env: %v", err)
	}
	if err := os.Setenv("BDA_DB_HOST", "localhost"); err != nil {
		t.Fatalf("Failed to set env: %v", err)
	}
	if err := os.Setenv("BDA_DB_PASSWORD", "test-password"); err != nil {
		t.Fatalf("Failed to set env: %v", err)
	}
	if err := os.Setenv("BDA_S3_BUCKET", "test-bucket"); err != nil {
		t.Fatalf("Failed to set env: %v", err)
	}
	defer cleanupEnv(t)

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() failed: %v", err)
	}

	if cfg.ClientID != "test-client" {
		t.Errorf("ClientID = %v, want test-client", cfg.ClientID)
	}
}

func cleanupEnv(t *testing.T) {
	t.Helper()
	if err := os.Unsetenv("BDA_CLIENT_ID"); err != nil {
		t.Logf("Failed to unset env: %v", err)
	}
	if err := os.Unsetenv("BDA_DB_HOST"); err != nil {
		t.Logf("Failed to unset env: %v", err)
	}
	if err := os.Unsetenv("BDA_DB_PASSWORD"); err != nil {
		t.Logf("Failed to unset env: %v", err)
	}
	if err := os.Unsetenv("BDA_S3_BUCKET"); err != nil {
		t.Logf("Failed to unset env: %v", err)
	}
}
